defmodule Croma.List do
  use Croma.Monad

  @type t(a) :: [a]

  def pure(a), do: [a]

  def bind(l, f), do: Enum.flat_map(l, f)
end
