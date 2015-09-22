defmodule Croma.Result do
  @moduledoc """
  A simple data structure to represent a result of computation that can either succeed or fail,
  in the form of `{:ok, any}` or `{:error, any}`.

  This module provides implementation of `Croma.Monad` interface for `Croma.Result.t`.
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

  @type t(a) :: {:ok, a} | {:error, any}

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
  Returns the value associated with `:ok` in the given `Croma.Result`.
  Returns `nil` if the argument is in the form of `{:error, _}`.

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
  Returns the value associated with `:ok` in the given `Croma.Result`.
  Returns `default` if the argument is in the form of `{:error, _}`.

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
  Returns the value associated with `:ok` in the given `Croma.Result`.
  Raises `ArgumentError` if the argument is in the form of `{:error, _}`.

  ## Examples
      iex> Croma.Result.get!({:ok, 1})
      1

      iex> Croma.Result.get!({:error, :foo})
      ** (ArgumentError) result is not :ok; element not present
  """
  defun get!(result :: t(a)) :: a when a: any do
    {:ok   , val} -> val
    {:error, _  } -> raise ArgumentError, message: "result is not :ok; element not present"
  end

  @doc """
  Returns true if the given argument is in the form of `{:ok, _value}`.
  """
  defun ok?(result :: t(a)) :: boolean when a: any do
    {:ok   , _} -> true
    {:error, _} -> false
  end

  @doc """
  Returns true if the given argument is in the form of `{:error, _}`.
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
  Tries to take one `Croma.Result` in `:ok` state from the given two.
  If the first `Croma.Result` is in `:ok` state it is returned.
  Otherwise the second `Croma.Result` is returned.
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

  defmodule ErrorReason do
    @moduledoc false

    defun add_context(reason :: term, context :: atom) :: {term, [atom]} do
      ({reason, contexts}, context) -> {reason, [context | contexts]}
      (term              , context) -> {term  , [context           ]}
    end
  end
end
