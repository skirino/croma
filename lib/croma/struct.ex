import Croma.Defun
alias Croma.Result, as: R

defmodule Croma.Struct do
  def field_default_pairs(fields) do
    Enum.map(fields, fn {key, mod} ->
      default = try do
        mod.default
      rescue
        _ -> nil
      end
      {key, default}
    end)
  end

  def field_type_pairs(fields) do
    Enum.map(fields, fn {key, mod} ->
      {key, quote do: unquote(mod).t}
    end)
  end

  def dict_get2(dict, key) do
    kv = Enum.find(dict, :error, fn {k, _} ->
      k == key || k == Atom.to_string(key)
    end)
    case kv do
      {_, v} -> {:ok, v}
      :error -> :error
    end
  end

  defmacro __using__(fields) do
    %Macro.Env{module: module} = __CALLER__
    quote context: Croma do
      @fields unquote(fields)
      defstruct Croma.Struct.field_default_pairs(@fields)
      @type t :: %unquote(module){unquote_splicing(Croma.Struct.field_type_pairs(fields))}

      defun new(dict: Dict.t) :: t do
        Enum.map(@fields, fn {field, mod} ->
          case Croma.Struct.dict_get2(dict, field) do
            {:ok, v} -> mod.validate(v)
            :error   -> {:ok, mod.default}
          end
          |> R.map(&{field, &1})
        end)
        |> R.sequence
        |> R.get!
        |> (fn kvs -> struct(__MODULE__, kvs) end).()
      end
    end
  end
end
