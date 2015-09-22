use Croma

defmodule Croma.DefunTest do
  use ExUnit.Case

  defmodule M do
    # with do-block as an ordinary keyword list
    defun a1 :: String.t, do: "a1"
    defun a2() :: String.t, do: "a2"
    defun a3(_i :: integer) :: String.t, do: "a3"

    # with do-block
    defun b1 :: String.t do
      "b1"
    end
    defun b2() :: String.t do
      "b2"
    end
    defun b3(_s :: String.t) :: String.t do
      "b3"
    end
    defun b4 :: String.t do
      "b4"
    end

    # function clauses
    defun c1(s :: String.t) :: String.t do
      s -> s
    end
    defun c2(x :: integer, y :: String.t) :: String.t do
      1, s   -> "1 #{s}"
      (2, s) -> "2 #{s}"
      (3, s) ->
        msg = s
        "3 #{msg}"
      (4, s) when is_binary(s) and byte_size(s) <= 5 -> "4 #{s}"
    end
    defun c3(x :: tuple) :: tuple do
      ({:ok, _} = t) -> t
    end

    # function with type parameter
    defun d1(_l :: [atom]) :: %{atom => String.t} do
      %{}
    end
    defun d2(_l :: [atom]) :: %{atom => String.t}, do: %{}
    defun d3(a :: a) :: a when a: term do
      a
    end
    defun d4(a :: a) :: a when [a: term], do: a
    defun d5(a :: a, _bs :: [b], _s :: String.t) :: list(a) when a: number, b: term do
      [a]
    end
    defun d6(l :: [a], f :: (a -> b)) :: [b] when a: number, b: boolean do
      ([], _) -> []
      ([h | t], f) when is_function(f) -> [f.(h) | d6(t, f)]
    end

    # function with default argument
    defun e1(i :: integer, s :: String.t \\ nil) :: String.t do
      "#{i} #{s}"
    end

    # private function
    # (Note that unused private functions will be removed at compile time
    #  and will cause compile error due to "spec for undefined function")
    defunp f1(x :: atom) :: String.t do
      Atom.to_string(x)
    end
    defunpt f2 :: String.t do
      f1(:foo)
    end

    # getter for compile-time typespec information
    spec = Module.get_attribute(__MODULE__, :spec) |> Macro.escape
    def typespecs, do: unquote(spec)
  end

  test "should define function" do
    assert M.a1                 == "a1"
    assert M.a2                 == "a2"
    assert M.a3(0)              == "a3"
    assert M.b1                 == "b1"
    assert M.b2                 == "b2"
    assert M.b3("foo")          == "b3"
    assert M.b4                 == "b4"
    assert M.c1("foo")          == "foo"
    assert M.c2(1, "foo")       == "1 foo"
    assert M.c2(2, "foo")       == "2 foo"
    assert M.c2(3, "foo")       == "3 foo"
    assert M.c2(4, "foo")       == "4 foo"
    assert M.c3({:ok, 0})       == {:ok, 0}
    assert M.d1([])             == %{}
    assert M.d2([])             == %{}
    assert M.d3(10)             == 10
    assert M.d4(10)             == 10
    assert M.d5(0, [], "")      == [0]
    assert M.d6([1], &is_nil/1) == [false]
    assert M.e1(1)              == "1 "
    assert M.e1(2, "bar")       == "2 bar"
    assert M.f2                 == "foo"

    catch_error M.c2(0, "foo")
    catch_error M.c2(4, :not_a_string)
    catch_error M.c2(4, "longer_than_5_bytes")
    catch_error M.c3({:error, :reason})
  end

  test "should add typespec" do
    typespec_codes = M.typespecs
    |> Enum.map(fn {:spec, expr, _env} -> Macro.to_string(expr) end)

    assert "a1() :: String.t()"                                        in typespec_codes
    assert "a2() :: String.t()"                                        in typespec_codes
    assert "a3(integer) :: String.t()"                                 in typespec_codes
    assert "b1() :: String.t()"                                        in typespec_codes
    assert "b2() :: String.t()"                                        in typespec_codes
    assert "b3(String.t()) :: String.t()"                              in typespec_codes
    assert "b4() :: String.t()"                                        in typespec_codes
    assert "c1(String.t()) :: String.t()"                              in typespec_codes
    assert "c2(integer, String.t()) :: String.t()"                     in typespec_codes
    assert "d1([atom]) :: %{atom => String.t()}"                       in typespec_codes
    assert "d2([atom]) :: %{atom => String.t()}"                       in typespec_codes
    assert "d3(a) :: a when a: term"                                   in typespec_codes
    assert "d4(a) :: a when a: term"                                   in typespec_codes
    assert "d5(a, [b], String.t()) :: list(a) when a: number, b: term" in typespec_codes
    assert "d6([a], (a -> b)) :: [b] when a: number, b: boolean"       in typespec_codes
    assert "e1(integer, String.t()) :: String.t()"                     in typespec_codes
    assert "f1(atom) :: String.t()"                                    in typespec_codes
    assert "f2() :: String.t()"                                        in typespec_codes
  end

  defmodule M2 do
    defun i1(i :: g[integer]) :: integer, do: i
    defun i2(i :: g[pos_integer]) :: pos_integer, do: i

    defun s1(s :: g[String.t]) :: String.t, do: s
    alias String, as: S1
    defun s2(s :: g[S1.t]) :: S1.t, do: s
    defun s3(s :: g[Croma.String.t]) :: Croma.String.t, do: s
    alias Croma.String, as: S2
    defun s4(s :: g[S2.t]) :: S2.t, do: s

    defun l1(l :: g[[]]) :: [], do: l
    defun l2(l :: g[[atom]]) :: [atom], do: l
    defun l3(l :: g[list]) :: list, do: l
    defun l4(l :: g[list(atom)]) :: list(atom), do: l

    defun f(d :: g[Dict.t], p :: g[pos_integer], n :: g[number] \\ 0.5) :: :ok, do: :ok
  end

  test "should define function with guard" do
    assert      M2.i1(0) == 0
    catch_error M2.i1(nil)
    catch_error M2.i2(0)
    assert      M2.i2(1) == 1

    assert      M2.s1("a") == "a"
    catch_error M2.s1(:a)
    assert      M2.s2("a") == "a"
    catch_error M2.s2(:a)
    assert      M2.s3("a") == "a"
    catch_error M2.s3(:a)
    assert      M2.s4("a") == "a"
    catch_error M2.s4(:a)

    assert      M2.l1([]) == []
    assert      M2.l2([]) == []
    assert      M2.l3([]) == []
    assert      M2.l4([]) == []
    catch_error M2.l1(nil)
    catch_error M2.l2(nil)
    catch_error M2.l3(nil)
    catch_error M2.l4(nil)

    assert      M2.f([] , 1, 0.5) == :ok
    assert      M2.f(%{}, 2, 0  ) == :ok
    catch_error M2.f("" , 1, 0.5)
    catch_error M2.f([] , 0)
  end

  defmodule M3 do
    defmodule S do
      use Croma.SubtypeOfString, pattern: ~r/^foo|bar$/
    end
    defun f1(s :: v[S.t]) :: S.t, do: s

    defmodule A do
      use Croma.SubtypeOfAtom, values: [:foo, :bar]
    end
    defun f2(a :: v[A.t]) :: A.t do
      a
    end

    defun f3(sg :: g[String.t], sv :: v[S.t], ag :: g[atom], av :: v[A.t]) :: String.t do
      "#{sg} #{sv} #{ag} #{av}"
    end

    @type t :: integer
    def validate(v) do
      if rem(v, 2) == 0, do: {:ok, v}, else: {:error, :odd}
    end
    defun f4(i :: v[t]) :: t do
      i
    end
  end

  test "should define function with argument validation" do
    assert      M3.f1("foo" ) == "foo"
    assert      M3.f1("bar" ) == "bar"
    catch_error M3.f1("baz")

    assert      M3.f2(:foo ) == :foo
    assert      M3.f2("foo") == :foo
    assert      M3.f2(:bar ) == :bar
    assert      M3.f2("bar") == :bar
    catch_error M3.f2(:baz )
    catch_error M3.f2("baz")

    assert      M3.f3("foo", "bar", :foo , :bar) == "foo bar foo bar"
    catch_error M3.f3(:foo , "bar", :foo , :bar)
    catch_error M3.f3("foo", "baz", :foo , :bar)
    catch_error M3.f3("foo", "bar", "foo", :bar)
    catch_error M3.f3("foo", "bar", :foo , :baz)

    assert      M3.f4(0) == 0
    catch_error M3.f4(1)
  end
end
