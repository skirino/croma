defmodule Croma.MonadTest do
  use ExUnit.Case
  use ExCheck
  alias Croma.Result, as: R

  def id(a), do: a

  def int2result(i) do
    if rem(i, 2) == 0, do: {:ok, i}, else: {:error, i}
  end

  test "Result as Monad" do
    r = R.pure(1)
    assert r == {:ok, 1}

    assert R.bind({:ok   , 0   }, &int2result/1) == {:ok   , 0   }
    assert R.bind({:ok   , 1   }, &int2result/1) == {:error, 1   }
    assert R.bind({:error, :foo}, &int2result/1) == {:error, :foo}
  end

  test "Result as Functor" do
    assert {:ok   , 1   } |> R.map(&(&1 + 1)) == {:ok   , 2   }
    assert {:error, :foo} |> R.map(&(&1 + 1)) == {:error, :foo}
  end

  property :functor_law1 do
    for_all x in int do
      r = int2result(x)
      R.map(r, &id/1) == r
    end
  end

  property :functor_law2 do
    f1  = fn x -> x + 1 end
    f2  = fn x -> x * 2 end
    f12 = fn x -> x |> f1.() |> f2.() end
    for_all x in int do
      r = int2result(x)
      r |> R.map(f1) |> R.map(f2) == r |> R.map(f12)
    end
  end

  test "Result as Applicative" do
    rf = R.pure(fn x -> x + 1 end)
    assert R.ap({:ok   , 1   }, rf) == {:ok, 2}
    assert R.ap({:error, :foo}, rf) == {:error, :foo}
  end

  property :applicative_law1_identity do
    for_all x in int do
      r = int2result(x)
      R.ap(r, R.pure(&id/1)) == r
    end
  end

  property :applicative_law2_homomorphism do
    f = fn i -> i + 1 end
    for_all x in int do
      R.ap(R.pure(x), R.pure(f)) == R.pure(f.(x))
    end
  end

  property :applicative_law3_interchange do
    rf = R.pure(fn i -> i + 1 end)
    for_all x in int do
      applier = fn f -> f.(x) end
      R.ap(R.pure(x), rf) == R.ap(rf, R.pure(applier))
    end
  end

  property :applicative_law4_composition do
    ru = R.pure(fn i -> i + 1 end)
    rv = R.pure(fn i -> i * 2 end)
    compose = fn f1 ->
      fn f2 ->
        fn x -> f1.(f2.(x)) end
      end
    end
    for_all x in int do
      r = int2result(x)
      R.ap(r, R.ap(rv, R.ap(ru, R.pure(compose)))) == r |> R.ap(rv) |> R.ap(ru)
    end
  end

  property :sequence do
    for_all l in list(int) do
      result = Enum.map(l, &int2result/1) |> R.sequence
      if Enum.all?(l, &(rem(&1, 2) == 0)) do
        result == {:ok, l}
      else
        result |> elem(0) == :error
      end
    end
  end

  property :monad_law1 do
    f = fn i -> R.pure(i + 1) end
    for_all i in int do
      R.bind(R.pure(i), f) == f.(i)
    end
  end

  property :monad_law2 do
    for_all i in int do
      r = int2result(i)
      R.bind(r, &R.pure/1) == r
    end
  end

  property :monad_law3 do
    k = fn i -> R.pure(i + 1) end
    h = fn i -> R.pure(i * 2) end
    for_all i in int do
      r = int2result(i)
      R.bind(r, fn x -> R.bind(k.(x), h) end) == r |> R.bind(k) |> R.bind(h)
    end
  end

  test "Haskell-like do-notation" do
    require R
    r1 = {:ok   , 1   }
    r2 = {:ok   , 2   }
    re = {:error, :foo}

    r = R.m do
    end
    assert r == nil

    r = R.m do
      pure 10
    end
    assert r == {:ok, 10}

    r = R.m do
      a <- r1
      b <- r2
      pure a + b
    end
    assert r == {:ok, 3}

    r = R.m do
      a <- r1
      e <- re
      b <- r2
      pure a + b
    end
    assert r == re
  end
end
