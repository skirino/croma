import Croma.Defun
alias Croma.Result, as: R

defmodule Croma.TypeGen do
  @moduledoc """
  Module that defines macros for ad-hoc module definitions.

  `Croma` leverages Elixir's lightweight module syntax and advocate coding styles to define many modules.
  Macros in this module helps defining modules in an ad-hoc way (in other words "in-line") based on existing modules.
  """

  @doc """
  Creates a new module that represents a nilable type, based on the given module `module`.

  The module passed to `nilable/1` must define the following members:

  - `@type t`
  - `@spec validate(term) :: Croma.Result.t(t)`

  Using the above members `nilable/1` generates a new module that also defines the same members:

  - `@type t :: nil | module.t`
  - `@spec validate(term) :: Croma.Result.t(t)`

  ## Examples
      iex> use Croma
      ...> defmodule I do
      ...>   use Croma.SubtypeOfInt, min: 0
      ...> end

  This is useful in defining a struct with nilable fields using `Croma.Struct`.

      ...> defmodule S do
      ...>   use Croma.Struct, not_nilable_int: I, nilable_int: Croma.TypeGen.nilable(I)
      ...> end

      ...> S.new([not_nilable_int: 0, nilable_int: nil])
      %S{nilable_int: nil, not_nilable_int: 0}
  """
  defmacro nilable(mod) do
    nilable_impl(Macro.expand(mod, __CALLER__), Macro.Env.location(__CALLER__))
  end

  defp nilable_impl(mod, location) do
    q = quote do
      @type t :: nil | unquote(mod).t

      defun validate(value: term) :: R.t(t) do
        nil -> {:ok, nil}
        v   -> case unquote(mod).validate(v) do
          {:ok   , _     } = r -> r
          {:error, reason}     -> {:error, R.ErrorReason.add_context(reason, __MODULE__)}
        end
      end
    end
    name = Module.concat(Croma.TypeGen.Nilable, mod)
    ensure_module_defined(name, q, location)
    name
  end

  @doc """
  An ad-hoc version of `Croma.SubtypeOfList`.
  Options for `Croma.SubtypeOfList` are not available in `list_of/1`.
  Usage of `list_of/1` macro is the same as `nilable/1`.
  """
  defmacro list_of(mod) do
    list_of_impl(Macro.expand(mod, __CALLER__), Macro.Env.location(__CALLER__))
  end

  defp list_of_impl(mod, location) do
    q = quote do
      @type t :: [unquote(mod).t]

      defun validate(list: term) :: R.t(t) do
        l when is_list(l) ->
          Enum.map(l, &unquote(mod).validate/1) |> R.sequence
        _ -> {:error, {:invalid_value, [__MODULE__]}}
      end
    end
    name = Module.concat(Croma.TypeGen.ListOf, mod)
    ensure_module_defined(name, q, location)
    name
  end

  defp ensure_module_defined(name, quoted_expr, location) do
    # Use processes' registered names to remember whether already defined or not
    # (Using `module_info/0` leads to try-rescue, which results in strange compilation error)
    case Agent.start(fn -> nil end, [name: name]) do
      {:ok   , _pid            } -> Module.create(name, quoted_expr, location)
      {:error, _already_defined} -> nil
    end
  end
end
