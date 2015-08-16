defmodule Croma.Struct do
  @moduledoc """
  Utility module to define structs and some helper functions.

  Using this module requires to prepare modules that represent each struct field.
  Each of per-field module must provide the following members:

  - required: `@type t`
  - required: `@spec validate(term) :: Croma.Result.t(t)`
  - optional: `@spec default :: t`

  Some helpers for defining such per-field modules are available.

  - `Croma.SubtypeOfInt`
  - `Croma.SubtypeOfFloat`
  - `Croma.SubtypeOfString`
  - `Croma.SubtypeOfAtom`
  - `Croma.SubtypeOfList`

  To define a struct, `use` this module with a keyword list:

      defmodule S do
        use Croma.Struct, field1_name: Field1Module, field2_name: Field2Module
      end

  Then the above code is converted to `defstruct` along with `@type t`.

  This module also generates the following functions.

  - `@spec new(Dict.t) :: t`
  - `@spec validate(term) :: Croma.Result.t(t)`
  - `@spec update(t, Dict.t) :: Croma.Result.t(t)`

  ## Examples
      iex> defmodule F do
      ...>   @type t :: integer
      ...>   def validate(i) when is_integer(i), do: {:ok, i}
      ...>   def validate(_), do: {:error, :invalid_f}
      ...>   def default, do: 0
      ...> end

      ...> defmodule S do
      ...>   use Croma.Struct, f: F
      ...> end

      ...> S.validate([f: 5])
      {:ok, %S{f: 5}}

      ...> S.validate(%{f: "not_an_integer"})
      {:error, :invalid_f}

      ...> s = S.new([])
      %S{f: 0}

      ...> S.update(s, [f: 2])
      {:ok, %S{f: 2}}

      ...> S.update(s, %{"f" => "not_an_integer"})
      {:error, :invalid_f}
  """

  import Croma.Defun
  alias Croma.Result, as: R

  @doc false
  def field_type_pairs(fields) do
    Enum.map(fields, fn {key, mod} ->
      {key, quote do: unquote(mod).t}
    end)
  end

  @doc false
  def dict_get2(dict, key) do
    Enum.find_value(dict, :error, fn {k, v} ->
      if k == key || k == Atom.to_string(key), do: {:ok, v}
    end)
  end

  defmacro __using__(fields) do
    %Macro.Env{module: module} = __CALLER__

    quote context: Croma, bind_quoted: [module: module, fields: fields] do
      @fields fields
      defstruct Keyword.keys(@fields)
      field_type_pairs = Croma.Struct.field_type_pairs(@fields)
      @type t :: %unquote(module){unquote_splicing(field_type_pairs)}

      @doc """
      Returns a new instance of #{__MODULE__} by using the given `dict` and the default value of each field.
      The values in the `dict` are validated by each field's `validate/1` function.
      Raises if invalid value is found.
      """
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

      @doc """
      Checks that the given `dict` is valid or not by using each field's `validate/1` function.
      Returns `{:ok, valid_struct}` or `{:error, reason}`.
      """
      defun validate(dict: Dict.t) :: R.t(t) do
        dict when is_list(dict) or is_map(dict) ->
          kv_results = Enum.map(@fields, fn {field, mod} ->
            case Croma.Struct.dict_get2(dict, field) do
              {:ok, v} -> v
              :error   -> nil
            end
            |> mod.validate
            |> R.map(&{field, &1})
          end)
          case R.sequence(kv_results) do
            {:ok   , kvs   } -> {:ok, struct(__MODULE__, kvs)}
            {:error, reason} -> {:error, R.ErrorReason.add_context(reason, __MODULE__)}
          end
        _ -> {:error, {:invalid_value, [__MODULE__]}}
      end

      @doc """
      Updates an existing instance of #{__MODULE__} with the given `dict`.
      The values in the `dict` are validated by each field's `validate/1` function.
      Returns `{:ok, valid_struct}` or `{:error, reason}`.
      """
      defun update(s: t, dict: Dict.t) :: R.t(t) do
        (%{__struct__: __MODULE__} = s, dict) when is_list(dict) or is_map(dict) ->
          kv_results = Enum.map(@fields, fn {field, mod} ->
            case Croma.Struct.dict_get2(dict, field) do
              {:ok, v} -> mod.validate(v) |> R.map(&{field, &1})
              :error   -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)
          case R.sequence(kv_results) do
            {:ok   , kvs   } -> {:ok, struct(s, kvs)}
            {:error, reason} -> {:error, R.ErrorReason.add_context(reason, __MODULE__)}
          end
      end
    end
  end
end
