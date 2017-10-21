import Croma.Defun
alias Croma.Result, as: R

defmodule Croma.TypeGen do
  @moduledoc """
  Module that defines macros for ad-hoc (in other words "in-line") module definitions.
  """

  @doc """
  Creates a new module that represents a nilable type, based on the given type module `module`.

  Using the given type module `nilable/1` generates a new module that defines:

  - `@type t :: nil | module.t`
  - `@spec valid?(term) :: boolean`
  - `@spec default() :: nil`
  - If the given module exports `new/1`
      - `@spec new(term) :: Croma.Result.t(t)`
      - `@spec new!(term) :: t`

  This is useful in defining a struct with nilable fields using `Croma.Struct`.

  ## Examples
      iex> use Croma
      ...> defmodule I do
      ...>   use Croma.SubtypeOfInt, min: 0
      ...> end
      ...> defmodule S do
      ...>   use Croma.Struct, fields: [not_nilable_int: I, nilable_int: Croma.TypeGen.nilable(I)]
      ...> end
      ...> S.new(%{not_nilable_int: 0, nilable_int: nil})
      %S{nilable_int: nil, not_nilable_int: 0}
  """
  defmacro nilable(module) do
    nilable_impl(Macro.expand(module, __CALLER__), Macro.Env.location(__CALLER__))
  end

  defp nilable_impl(mod, location) do
    module_body = Macro.escape(nilable_module_body(mod))
    quote bind_quoted: [mod: mod, module_body: module_body, location: location] do
      name = Module.concat(Croma.TypeGen.Nilable, mod)
      Croma.TypeGen.ensure_module_defined(name, module_body, location)
      name
    end
  end

  defp nilable_module_body(mod) do
    quote bind_quoted: [mod: mod] do
      @moduledoc false

      @mod mod
      @type t :: nil | unquote(@mod).t

      defun valid?(value :: term) :: boolean do
        nil -> true
        v   -> @mod.valid?(v)
      end

      # Invoking `module_info/1` on `mod` automatically compiles and loads the module if necessary.
      if {:new, 1} in @mod.module_info(:exports) do
        defun new(value :: term) :: R.t(t) do
          nil -> {:ok, nil}
          v   ->
            case @mod.new(v) do
              {:ok   , _     } = r -> r
              {:error, reason}     -> {:error, R.ErrorReason.add_context(reason, __MODULE__)}
            end
        end

        defun new!(term :: term) :: t do
          new(term) |> R.get!()
        end
      end

      defun default() :: t, do: nil
    end
  end

  @doc """
  An ad-hoc version of `Croma.SubtypeOfList`.

  Options for `Croma.SubtypeOfList` are not available in `list_of/1`.
  Usage of `list_of/1` macro is the same as `nilable/1`.
  """
  defmacro list_of(module) do
    list_of_impl(Macro.expand(module, __CALLER__), Macro.Env.location(__CALLER__))
  end

  defp list_of_impl(mod, location) do
    module_body = Macro.escape(list_of_module_body(mod))
    quote bind_quoted: [mod: mod, module_body: module_body, location: location] do
      name = Module.concat(Croma.TypeGen.ListOf, mod)
      Croma.TypeGen.ensure_module_defined(name, module_body, location)
      name
    end
  end

  defp list_of_module_body(mod) do
    quote bind_quoted: [mod: mod] do
      @moduledoc false

      @mod mod
      @type t :: [unquote(@mod).t]

      defun valid?(list :: term) :: boolean do
        l when is_list(l) -> Enum.all?(l, fn v -> @mod.valid?(v) end)
        _                 -> false
      end

      # Invoking `module_info/1` on `mod` automatically compiles and loads the module if necessary.
      if {:new, 1} in @mod.module_info(:exports) do
        defun new(list :: term) :: R.t(t) do
          l when is_list(l) -> Enum.map(l, &@mod.new/1) |> R.sequence()
          _                 -> {:error, {:invalid_value, [__MODULE__]}}
        end

        defun new!(term :: term) :: t do
          new(term) |> R.get!()
        end
      end

      defun default() :: t, do: []
    end
  end

  @doc """
  Creates a new module that represents a sum type of the given types.

  The argument must be a list of type modules.
  """
  defmacro union(modules) do
    ms = Enum.map(modules, fn m -> Macro.expand(m, __CALLER__) end)
    if Enum.empty?(ms), do: raise "Empty union is not allowed"
    union_impl(ms, Macro.Env.location(__CALLER__))
  end

  defp union_impl(modules, location) do
    module_body = Macro.escape(union_module_body(modules))
    quote bind_quoted: [modules: modules, module_body: module_body, location: location] do
      hash = Enum.map(modules, &Atom.to_string/1) |> :erlang.md5() |> Base.encode16()
      name = Module.concat(Croma.TypeGen.Union, hash)
      Croma.TypeGen.ensure_module_defined(name, module_body, location)
      name
    end
  end

  defp union_module_body(modules) do
    quote bind_quoted: [modules: modules] do
      @moduledoc false

      @modules modules
      @type t :: unquote(Enum.map(@modules, fn m -> quote do: unquote(m).t end) |> Croma.TypeUtil.list_to_type_union())

      defun valid?(value :: term) :: boolean do
        Enum.any?(@modules, fn mod -> mod.valid?(value) end)
      end
    end
  end

  @doc """
  Creates a new module that simply represents a type whose sole member is the given value.

  Only atoms and integers are supported.
  """
  defmacro fixed(value) do
    fixed_impl(value, Macro.Env.location(__CALLER__))
  end

  defp fixed_impl(value, location) when is_atom(value) or is_integer(value) do
    module_body = Macro.escape(fixed_module_body(value))
    quote bind_quoted: [value: value, module_body: module_body, location: location] do
      hash = :erlang.term_to_binary(value) |> :erlang.md5() |> Base.encode16()
      name = Module.concat(Croma.TypeGen.Fixed, hash)
      Croma.TypeGen.ensure_module_defined(name, module_body, location)
      name
    end
  end

  defp fixed_module_body(value) do
    quote bind_quoted: [value: value] do
      @moduledoc false

      @value value
      @type t :: unquote(@value)

      defun valid?(v :: term) :: boolean do
        v == @value
      end

      defun default() :: t, do: @value
    end
  end

  @doc false
  def ensure_module_defined(name, quoted_expr, location) do
    # Skip creating module if its beam file is already generated by previous compilation
    if :code.which(name) == :non_existing do
      # Use processes' registered names (just because it's easy) to remember whether already defined or not
      # (Using `module_info` leads to try-rescue, which results in compilation error:
      #  see https://github.com/elixir-lang/elixir/issues/4055)
      case Agent.start(fn -> nil end, [name: name]) do
        {:ok   , _pid            } -> Module.create(name, quoted_expr, location)
        {:error, _already_defined} -> nil
      end
    end
  end

  @doc false
  def define_nilable_and_list_of(mod) do
    location = Macro.Env.location(__ENV__)
    q1 = nilable_impl(mod, location)
    q2 = list_of_impl(mod, location)
    Code.eval_quoted(q1, [], __ENV__)
    Code.eval_quoted(q2, [], __ENV__)
  end
end

# Predefine some type modules to avoid warnings when generated by multiple mix projects
defmodule Croma.PredefineVariantsOfBuiltinTypes do
  @moduledoc false

  Croma.BuiltinType.all() |> Enum.each(&Croma.TypeGen.define_nilable_and_list_of/1)
end
