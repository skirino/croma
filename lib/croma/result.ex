defmodule Croma.Result do
  @moduledoc """
  A simple data structure to represent a result of computation that can either succeed or fail,
  in the form of `{:ok, any}` or `{:error, any}`.

  In addition to many utility functions, this module also provides implementation of
  `Croma.Monad` interface for `t:Croma.Result.t/1`.
  This enables the following Haskell-ish syntax:

      iex> use Croma
      ...> Croma.Result.m do
      ...>   x <- {:ok, 1}
      ...>   y <- {:ok, 2}
      ...>   pure x + y
      ...> end
      {:ok, 3}

  The above code is expanded to the code that uses `pure/1` and `bind/2`.

      Croma.Result.bind({:ok, 1}, fn x ->
        Croma.Result.bind({:ok, 2}, fn y ->
          Croma.Result.pure(x + y)
        end)
      end)

  This is useful when handling multiple computations that may go wrong in a short-circuit manner:

      iex> use Croma
      ...> Croma.Result.m do
      ...>   x <- {:error, :foo}
      ...>   y <- {:ok, 2}
      ...>   pure x + y
      ...> end
      {:error, :foo}
  """

  use Croma.Monad
  import Croma.Defun

  @type t(a, b) :: {:ok, a} | {:error, b}
  @type t(a)    :: t(a, any)

  @doc """
  Implementation of `pure` operation of Monad (or Applicative).
  Wraps the given value into a `Croma.Result`, i.e., returns `{:ok, arg}`.
  """
  def pure(a), do: {:ok, a}

  @doc """
  Implementation of `bind` operation of Monad.
  Executes the given function if the result is in `:ok` state; otherwise returns the failed result.
  """
  def bind({:ok, val}          , f), do: f.(val)
  def bind({:error, _} = result, _), do: result

  # Override default implementation to make it tail-recursive
  def sequence(l) do
    sequence_impl(l, [])
  end

  defunp sequence_impl(l :: [t(a)], acc :: [a]) :: t([a]) when a: any do
    ([]     , acc) -> {:ok, Enum.reverse(acc)}
    ([h | t], acc) ->
      case h do
        {:ok   , v}     -> sequence_impl(t, [v | acc])
        {:error, _} = e -> e
      end
  end

  @doc """
  Returns the value associated with `:ok` in the given result.
  Returns `nil` if the result is in the form of `{:error, _}`.

  ## Examples
      iex> Croma.Result.get({:ok, 1})
      1

      iex> Croma.Result.get({:error, :foo})
      nil
  """
  defun get(result :: t(a)) :: nil | a when a: any do
    {:ok   , val} -> val
    {:error, _  } -> nil
  end

  @doc """
  Returns the value associated with `:ok` in the given result.
  Returns `default` if the result is in the form of `{:error, _}`.

  ## Examples
      iex> Croma.Result.get({:ok, 1}, 0)
      1

      iex> Croma.Result.get({:error, :foo}, 0)
      0
  """
  defun get(result :: t(a), default :: a) :: a when a: any do
    ({:ok   , val}, _      ) -> val
    ({:error, _  }, default) -> default
  end

  @doc """
  Returns the value associated with `:ok` in the given result.
  Raises `ArgumentError` if the result is in the form of `{:error, _}`.

  ## Examples
      iex> Croma.Result.get!({:ok, 1})
      1

      iex> Croma.Result.get!({:error, :foo})
      ** (ArgumentError) element not present: {:error, :foo}
  """
  defun get!(result :: t(a)) :: a when a: any do
    {:ok   , val}     -> val
    {:error, _  } = e -> raise ArgumentError, message: "element not present: #{inspect(e)}"
  end

  @doc """
  Returns true if the given result is in the form of `{:ok, _value}`.
  """
  defun ok?(result :: t(a)) :: boolean when a: any do
    {:ok   , _} -> true
    {:error, _} -> false
  end

  @doc """
  Returns true if the given result is in the form of `{:error, _}`.
  """
  defun error?(result :: t(a)) :: boolean when a: any do
    !ok?(result)
  end

  @doc """
  Executes the given function within a try-rescue block and wraps the return value as `{:ok, retval}`.
  If the function raises an exception, `try/1` returns the exception in the form of `{:error, exception}`.

  ## Examples
      iex> Croma.Result.try(fn -> 1 + 1 end)
      {:ok, 2}

      iex> Croma.Result.try(fn -> raise "foo" end)
      {:error, %RuntimeError{message: "foo"}}
  """
  defun try(f :: (-> a)) :: t(a) when a: any do
    try do
      {:ok, f.()}
    rescue
      e -> {:error, {e, [:try]}}
    end
  end

  @doc """
  Tries to take one result in `:ok` state from the given two.
  If the first result is in `:ok` state it is returned.
  Otherwise the second result is returned.
  Note that `or_else/2` is a macro instead of a function in order to short-circuit evaluation of the second argument,
  i.e. the second argument is evaluated only when the first argument is in `:error` state.
  """
  defmacro or_else(result1, result2) do
    quote do
      case unquote(result1) do
        {:ok   , _} = r1 -> r1
        {:error, _}      -> unquote(result2)
      end
    end
  end

  @doc """
  Transforms a result by applying a function to its contained `:error` value.
  If the given result is in `:ok` state it is returned without using the given function.
  """
  defun map_error(result :: t(a), f :: ((any) -> any)) :: t(a) when a: any do
    case result do
      {:error, e}  -> {:error, f.(e)}
      {:ok, _} = r -> r
    end
  end

  @doc """
  Wraps a given value in an `:ok` tuple if `mod.valid?/1` returns true for the value.
  Otherwise returns an `:error` tuple.
  """
  defun wrap_if_valid(v :: a, mod :: module) :: t(a) when a: any do
    case mod.valid?(v) do
      true  -> {:ok, v}
      false -> {:error, {:invalid_value, [mod]}}
    end
  end

  @doc """
  Based on existing functions that return `Croma.Result.t(any)`, defines functions that raise on error.

  Each generated function simply calls the specified function and then passes the returned value to `Croma.Result.get!/1`.

  ## Examples
      iex> defmodule M do
      ...>   def f(a) do
      ...>     {:ok, a + 1}
      ...>   end
      ...>   Croma.Result.define_bang_version_of(f: 1)
      ...> end
      iex> M.f(1)
      {:ok, 2}
      iex> M.f!(1)
      2

  If appropriate spec of original function is available, spec of the bang version is also declared.
  For functions that have default arguments it's necessary to explicitly pass all arities to `Croma.Result.define_bang_version_of/1`.
  """
  defmacro define_bang_version_of(name_arity_pairs) do
    quote bind_quoted: [name_arity_pairs: name_arity_pairs, caller: Macro.escape(__CALLER__)] do
      specs = Module.get_attribute(__MODULE__, :spec)
      Enum.each(name_arity_pairs, fn {name, arity} ->
        spec = Enum.find_value(specs, &Croma.Result.Impl.match_and_convert_spec(name, arity, &1, caller))
        if spec do
          @spec unquote(spec)
        end
        vars = Croma.Result.Impl.make_vars(arity, __MODULE__)
        def unquote(:"#{name}!")(unquote_splicing(vars)) do
          unquote(name)(unquote_splicing(vars)) |> Croma.Result.get!()
        end
      end)
    end
  end

  defmodule Impl do
    @moduledoc false

    def match_and_convert_spec(name, arity, spec, caller_env) do
      case spec do
        {:spec, {:::, meta1, [{^name, meta2, args}, ret_type]}, _} when length(args) == arity ->
          make_spec_fun = fn r -> {:::, meta1, [{:"#{name}!", meta2, args}, r]} end
          case ret_type do
            {:ok, r} -> make_spec_fun.(r)
            {:|, _, types} ->
              Enum.find_value(types, fn
                {:ok, r} -> make_spec_fun.(r)
                _        -> nil
              end)
            {{:., _, [mod_alias, :t]}, _, r} ->
              if Macro.expand(mod_alias, caller_env) == Croma.Result, do: make_spec_fun.(hd(r)), else: nil
            _ -> nil
          end
        _ -> nil
      end
    end

    def make_vars(n, module) do
      if n == 0 do
        []
      else
        Enum.map(0 .. n-1, fn i -> Macro.var(String.to_atom("arg#{i}"), module) end)
      end
    end
  end

  defmodule ErrorReason do
    @moduledoc false

    @type context :: module | {module, atom}

    defun add_context(reason :: term, context :: context) :: {term, [context]} do
      ({reason, contexts}, context) -> {reason, [context | contexts]}
      (term              , context) -> {term  , [context           ]}
    end
  end
end
