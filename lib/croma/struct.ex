defmodule Croma.Struct do
  @moduledoc """
  Utility module to define structs and some helper functions.

  Using this module requires to prepare modules that represent each struct field.
  Each of per-field module must provide the following members:

  - required: `@type t`
  - required: `@spec validate(term) :: Croma.Result.t(t)`
  - optional: `@spec default :: t`

  Some helpers for defining such per-field modules are available.

  - Wrappers of built-in types such as `Croma.String`, `Croma.Integer`, etc.
  - Utility modules such as `Croma.SubtypeOfString` to define "subtypes" of existing types.
  - Ad-hoc module generators defined in `Croma.TypeGen`.

  To define a struct, `use` this module with a keyword list:

      defmodule S do
        use Croma.Struct, field1_name: Field1Module, field2_name: Field2Module
      end

  Then the above code is converted to `defstruct` along with `@type t`.

  This module also generates the following functions.

  - `@spec new(Dict.t) :: Croma.Result.t(t)`
  - `@spec new!(Dict.t) :: t`
  - `@spec validate(term) :: Croma.Result.t(t)`
  - `@spec validate!(term) :: t`
  - `@spec update(t, Dict.t) :: Croma.Result.t(t)`
  - `@spec update!(t, Dict.t) :: t`

  ## Examples
      iex> defmodule I do
      ...>   @type t :: integer
      ...>   def validate(i) when is_integer(i), do: {:ok, i}
      ...>   def validate(_), do: {:error, {:invalid_value, [__MODULE__]}}
      ...>   def default, do: 0
      ...> end

      ...> defmodule S do
      ...>   use Croma.Struct, i: I
      ...> end

      ...> S.validate([i: 5])
      ...> {:ok, %S{i: 5}}

      ...> S.validate(%{i: "not_an_integer"})
      ...> {:error, {:invalid_value, [S, I]}}

      ...> {:ok, s} = S.new([])
      ...> {:ok, %S{i: 0}}

      ...> S.update(s, [i: 2])
      ...> {:ok, %S{i: 2}}

      ...> S.update(s, %{"i" => "not_an_integer"})
      ...> {:error, {:invalid_value, [S, I]}}
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
  def dict_fetch2(dict, key) when is_list(dict) do
    Enum.find_value(dict, :error, fn {k, v} ->
      if k == key || k == Atom.to_string(key), do: {:ok, v}
    end)
  end
  def dict_fetch2(dict, key) when is_map(dict) do
    case Map.fetch(dict, key) do
      {:ok, _} = r -> r
      :error       -> Map.fetch(dict, Atom.to_string(key))
    end
  end

  defmacro __using__(fields) do
    %Macro.Env{module: module} = __CALLER__

    quote context: Croma, bind_quoted: [module: module, fields: fields] do
      @fields fields
      defstruct Keyword.keys(@fields)
      field_type_pairs = Croma.Struct.field_type_pairs(@fields)
      @type t :: %unquote(module){unquote_splicing(field_type_pairs)}

      @doc """
      Creates a new instance of #{__MODULE__} by using the given `dict` and the default value of each field.
      Returns `{:ok, valid_struct}` or `{:error, reason}`.
      The values in the `dict` are validated by each field's `validate/1` function.
      """
      defun new(dict: Dict.t) :: R.t(t) do
        rs = Enum.map(@fields, fn {field, mod} ->
          case Croma.Struct.dict_fetch2(dict, field) do
            {:ok, v} -> mod.validate(v)
            :error   ->
              try do
                {:ok, mod.default}
              rescue
                _ -> {:error, {:value_missing, [mod]}}
              end
          end
          |> R.map(&{field, &1})
        end)
        case R.sequence(rs) do
          {:ok   , kvs   } -> {:ok, struct(__MODULE__, kvs)}
          {:error, reason} -> {:error, R.ErrorReason.add_context(reason, __MODULE__)}
        end
      end

      @doc """
      A variant of `new/1` which returns `t` or raise if validation fails.
      In other words, `new/1` followed by `Croma.Result.get!/1`.
      """
      defun new!(dict: Dict.t) :: t do
        new(dict) |> R.get!
      end

      @doc """
      Checks that the given `dict` is valid or not by using each field's `validate/1` function.
      Returns `{:ok, valid_struct}` or `{:error, reason}`.
      """
      defun validate(dict: Dict.t) :: R.t(t) do
        dict when is_list(dict) or is_map(dict) ->
          kv_results = Enum.map(@fields, fn {field, mod} ->
            case Croma.Struct.dict_fetch2(dict, field) do
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
      A variant of `validate/1` which returns `t` or raise if validation fails.
      In other words, `validate/1` followed by `Croma.Result.get!/1`.
      """
      defun validate!(dict: Dict.t) :: t do
        validate(dict) |> R.get!
      end

      @doc """
      Updates an existing instance of #{__MODULE__} with the given `dict`.
      The values in the `dict` are validated by each field's `validate/1` function.
      Returns `{:ok, valid_struct}` or `{:error, reason}`.
      """
      defun update(s: t, dict: Dict.t) :: R.t(t) do
        (%{__struct__: __MODULE__} = s, dict) when is_list(dict) or is_map(dict) ->
          kv_results = Enum.map(@fields, fn {field, mod} ->
            case Croma.Struct.dict_fetch2(dict, field) do
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

      @doc """
      A variant of `update/2` which returns `t` or raise if validation fails.
      In other words, `update/2` followed by `Croma.Result.get!/1`.
      """
      defun update!(s: t, dict: Dict.t) :: t do
        update(s, dict) |> R.get!
      end
    end
  end
end
