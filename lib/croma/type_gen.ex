import Croma.Defun
alias Croma.Result, as: R
alias Croma.New1Existence

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

      New1Existence.store_mod_fun_args_to_evaluate(__MODULE__, {New1Existence, :has_new1?, [@mod]})

      if New1Existence.has_new1?(@mod, __MODULE__) do
        defun new(value :: term) :: R.t(t) do
          nil -> {:ok, nil}
          v   -> @mod.new(v) |> R.map_error(fn reason -> R.ErrorReason.add_context(reason, __MODULE__) end)
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

  Options:
  - `:define_default0?` - Boolean value that indicates whether to define `default/0` (which simply returns `[]`). Defaults to `true`.
  """
  defmacro list_of(module, options \\ []) do
    list_of_impl(Macro.expand(module, __CALLER__), Macro.Env.location(__CALLER__), options)
  end

  defp list_of_impl(mod, location, options) do
    module_body = Macro.escape(list_of_module_body(mod, options))
    quote bind_quoted: [mod: mod, module_body: module_body, location: location, options: options] do
      prefix = if Keyword.get(options, :define_default0?, true), do: Croma.TypeGen.ListOf, else: Croma.TypeGen.ListOfNoDefault0
      name = Module.concat(prefix, mod)
      Croma.TypeGen.ensure_module_defined(name, module_body, location)
      name
    end
  end

  defp list_of_module_body(mod, options) do
    quote bind_quoted: [mod: mod, options: options] do
      @moduledoc false

      @mod mod
      @type t :: [unquote(@mod).t]

      defun valid?(list :: term) :: boolean do
        l when is_list(l) -> Enum.all?(l, &@mod.valid?/1)
        _                 -> false
      end

      New1Existence.store_mod_fun_args_to_evaluate(__MODULE__, {New1Existence, :has_new1?, [@mod]})

      if New1Existence.has_new1?(@mod, __MODULE__) do
        defun new(list :: term) :: R.t(t) do
          l when is_list(l) -> Enum.map(l, &@mod.new/1) |> R.sequence()
          _                 -> {:error, {:invalid_value, [__MODULE__]}}
        end

        defun new!(term :: term) :: t do
          new(term) |> R.get!()
        end
      end

      if Keyword.get(options, :define_default0?, true) do
        defun default() :: t, do: []
      end
    end
  end

  @doc """
  Creates a new module that represents a sum type of the given types.

  The argument must be a list of type modules.
  Note that the specified types should be mutually disjoint;
  otherwise `new/1` can return unexpected results depending on the order of the type modules.
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

      module_flag_pairs = Enum.map(@modules, fn m -> {m, New1Existence.has_new1?(m, __MODULE__)} end)
      Enum.each(module_flag_pairs, fn {mod, has_new1} ->
        if has_new1 do
          defp call_new_or_validate(unquote(mod), v) do
            unquote(mod).new(v)
          end
        else
          defp call_new_or_validate(unquote(mod), v) do
            Croma.Result.wrap_if_valid(v, unquote(mod))
          end
        end
      end)

      defun new(v :: term) :: R.t(t) do
        new_impl(v, @modules) |> R.map_error(fn _ -> {:invalid_value, [__MODULE__]} end)
      end

      defp new_impl(v, [m]) do
        call_new_or_validate(m, v)
      end
      defp new_impl(v, [m | ms]) do
        require R
        call_new_or_validate(m, v) |> R.or_else(new_impl(v, ms))
      end

      defun new!(term :: term) :: t do
        new(term) |> R.get!()
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
    if :code.which(name) == :non_existing and lock_module_creation?(name) do
      Module.create(name, quoted_expr, location)
    end
  end

  defp lock_module_creation?(name) do
    # Use processes' registered names (just because it's easy) to remember whether already defined or not
    # (Using `module_info` leads to try-rescue, which results in compilation error:
    #  see https://github.com/elixir-lang/elixir/issues/4055)
    case Agent.start(fn -> nil end, [name: name]) do
      {:ok   , _pid            } -> true
      {:error, _already_defined} -> false
    end
  end

  @doc false
  def ensure_unlock_module_creation(name) do
    case GenServer.whereis(name) do
      nil -> :ok
      _   -> Agent.stop(name)
    end
  end

  @doc false
  def define_nilable_and_list_of(mod) do
    location = Macro.Env.location(__ENV__)
    q1 = nilable_impl(mod, location)
    q2 = list_of_impl(mod, location, [define_default0?: true ])
    q3 = list_of_impl(mod, location, [define_default0?: false])
    Code.eval_quoted(q1, [], __ENV__)
    Code.eval_quoted(q2, [], __ENV__)
    Code.eval_quoted(q3, [], __ENV__)
  end
end

# Predefine some type modules to avoid warnings when generated by multiple mix projects
defmodule Croma.PredefineVariantsOfBuiltinTypes do
  @moduledoc false

  Croma.BuiltinType.all() |> Enum.each(&Croma.TypeGen.define_nilable_and_list_of/1)
end
