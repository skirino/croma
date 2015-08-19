defmodule Croma.ListMonadTest do
  use ExUnit.Case

  test "Haskell-like do-notation" do
    require Croma.ListMonad

    l = Croma.ListMonad.m do
      x <- [1, 2, 3]
      y <- [10, 20]
      pure x + y
    end
    assert l == [11, 21, 12, 22, 13, 23]

    l = Croma.ListMonad.m do
      x <- [1, 2, 3]
      y <- []
      pure x + y
    end
    assert l == []
  end
end
