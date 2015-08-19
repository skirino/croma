defmodule Croma.ListMonad do
  @moduledoc """
  Implementation of `Croma.Monad` interface for built-in lists.

  This empowers the following Haskell-ish syntax for loops using lists:

      iex> use Croma
      ...> Croma.ListMonad.m do
      ...>   i <- [1, 2, 3]
      ...>   j <- [10, 20]
      ...>   pure i + j
      ...> end
      [11, 21, 12, 22, 13, 23]
  """

  use Croma.Monad

  @type t(a) :: [a]

  @doc """
  Implementation of `pure` operation of Monad (or Applicative).
  Wraps the given value into a list.
  """
  def pure(a), do: [a]

  @doc """
  Implementation of `bind` operation of Monad.
  Alias to `Enum.flat_map/2`.
  """
  def bind(l, f), do: Enum.flat_map(l, f)
end
