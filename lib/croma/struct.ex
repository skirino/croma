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

  defmacro __using__(fields) do
    %Macro.Env{module: module} = __CALLER__
    quote do
      defstruct Croma.Struct.field_default_pairs(unquote(fields))
      @type t :: %unquote(module){unquote_splicing(Croma.Struct.field_type_pairs(fields))}
    end
  end
end
