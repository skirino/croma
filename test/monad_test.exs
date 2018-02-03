defmodule Croma.MonadTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Croma.Result   , as: R
  alias Croma.ListMonad, as: L

  defp id(a), do: a

  defp int2result(i) do
    if rem(i, 2) == 0, do: {:ok, i}, else: {:error, i}
  end

  defp functor_law1(mod, f) do
    assert mod.map(f, &id/1) == f
  end

  property "result_functor_law1" do
    check all x <- integer() do
      r = int2result(x)
      functor_law1(R, r)
    end
  end

  property "list_functor_law1" do
    check all l <- list_of(integer()) do
      functor_law1(L, l)
    end
  end

  defp functor_law2(mod, f) do
    g1  = fn x -> x + 1 end
    g2  = fn x -> x * 2 end
    g12 = fn x -> x |> g1.() |> g2.() end
    assert f |> mod.map(g1) |> mod.map(g2) == f |> mod.map(g12)
  end

  property "result_functor_law2" do
    check all x <- integer() do
      r = int2result(x)
      functor_law2(R, r)
    end
  end

  property "list_functor_law2" do
    check all l <- list_of(integer()) do
      functor_law2(L, l)
    end
  end

  defp applicative_law1_identity(mod, a) do
    assert mod.ap(a, mod.pure(&id/1)) == a
  end

  property "result_applicative_law1" do
    check all x <- integer() do
      r = int2result(x)
      applicative_law1_identity(R, r)
    end
  end

  property "list_applicative_law1" do
    check all l <- list_of(integer()) do
      applicative_law1_identity(L, l)
    end
  end

  defp applicative_law2_homomorphism(mod, x) do
    f = fn i -> i + 1 end
    assert mod.ap(mod.pure(x), mod.pure(f)) == mod.pure(f.(x))
  end

  property "result_applicative_law2" do
    check all x <- integer() do
      applicative_law2_homomorphism(R, x)
    end
  end

  property "list_applicative_law2" do
    check all x <- integer() do
      applicative_law2_homomorphism(L, x)
    end
  end

  defp applicative_law3_interchange(mod, x) do
    af = mod.pure(fn i -> i + 1 end)
    applier = fn f -> f.(x) end
    assert mod.ap(mod.pure(x), af) == mod.ap(af, mod.pure(applier))
  end

  property "result_applicative_law3" do
    check all x <- integer() do
      applicative_law3_interchange(R, x)
    end
  end

  property "list_applicative_law3" do
    check all x <- integer() do
      applicative_law3_interchange(L, x)
    end
  end

  defp applicative_law4_compoisition(mod, a) do
    au = mod.pure(fn i -> i + 1 end)
    av = mod.pure(fn i -> i * 2 end)
    compose = fn f1 ->
      fn f2 ->
        fn x -> f1.(f2.(x)) end
      end
    end
    assert mod.ap(a, mod.ap(av, mod.ap(au, mod.pure(compose)))) == a |> mod.ap(av) |> mod.ap(au)
  end

  property "result_applicative_law4" do
    check all x <- integer() do
      r = int2result(x)
      applicative_law4_compoisition(R, r)
    end
  end

  property "list_applicative_law4" do
    check all l <- list_of(integer()) do
      applicative_law4_compoisition(L, l)
    end
  end

  defp monad_law1(mod, x) do
    f = fn i -> mod.pure(i + 1) end
    assert mod.bind(mod.pure(x), f) == f.(x)
  end

  property "result_monad_law1" do
    check all i <- integer() do
      monad_law1(R, i)
    end
  end

  property "list_monad_law1" do
    check all i <- integer() do
      monad_law1(L, i)
    end
  end

  defp monad_law2(mod, m) do
    assert mod.bind(m, &mod.pure/1) == m
  end

  property "result_monad_law2" do
    check all i <- integer() do
      r = int2result(i)
      monad_law2(R, r)
    end
  end

  property "list_monad_law2" do
    check all l <- list_of(integer()) do
      monad_law2(L, l)
    end
  end

  defp monad_law3(mod, m) do
    k = fn i -> mod.pure(i + 1) end
    h = fn i -> mod.pure(i * 2) end
    assert mod.bind(m, fn x -> mod.bind(k.(x), h) end) == m |> mod.bind(k) |> mod.bind(h)
  end

  property "result_monad_law3" do
    check all i <- integer() do
      r = int2result(i)
      monad_law3(R, r)
    end
  end

  property "list_monad_law3" do
    check all l <- list_of(integer()) do
      monad_law3(L, l)
    end
  end
end
