defmodule CromaTest do
  use ExUnit.Case

  defmodule DefunTest do
    use Croma

    # with do-block as an ordinary keyword list
    defun a1 :: String.t, do: "a1"
    defun a2() :: String.t, do: "a2"
    defun a3(_i: integer) :: String.t, do: "a3"

    # with do-block
    defun b1 :: String.t do
      "b1"
    end
    defun b2() :: String.t do
      "b2"
    end
    defun b3(_s: String.t) :: String.t do
      "b3"
    end
    defun b4 :: String.t do
      "b4"
    end

    # function clauses
    defun c1(s: String.t) :: String.t do
      s -> s
    end
    defun c2(x: integer, y: String.t) :: String.t do
      1, s   -> "1 #{s}"
      (2, s) -> "2 #{s}"
      (3, s) ->
        msg = s
        "3 #{msg}"
      (4, s) when is_binary(s) and byte_size(s) <= 5 -> "4 #{s}"
    end
    defun c3(x: tuple) :: tuple do
      ({:ok, _} = t) -> t
    end

    # function with type parameter
    defun d1(_l: [atom]) :: %{atom => String.t} do
      %{}
    end
    defun d2(_l: [atom]) :: %{atom => String.t}, do: %{}
    defun d3(a: a) :: a when a: term do
      a
    end
    defun d4(a: a) :: a when [a: term], do: a
    defun d5(a: a, _bs: [b], _s: String.t) :: list(a) when a: number, b: term do
      [a]
    end
    defun d6(l: [a], f: (a -> b)) :: [b] when a: number, b: boolean do
      ([], _) -> []
      ([h | t], f) when is_function(f) -> [f.(h) | d6(t, f)]
    end

    # function with default argument
    defun e1(i: integer, s: String.t \\ "foo") :: String.t do
      "#{i} #{s}"
    end

    # getter of compile-time typespec information
    spec = Module.get_attribute(__MODULE__, :spec) |> Macro.escape
    def typespecs, do: unquote(spec)
  end

  test "should define function" do
    assert DefunTest.a1                 == "a1"
    assert DefunTest.a2                 == "a2"
    assert DefunTest.a3(0)              == "a3"
    assert DefunTest.b1                 == "b1"
    assert DefunTest.b2                 == "b2"
    assert DefunTest.b3("foo")          == "b3"
    assert DefunTest.b4                 == "b4"
    assert DefunTest.c1("foo")          == "foo"
    assert DefunTest.c2(1, "foo")       == "1 foo"
    assert DefunTest.c2(2, "foo")       == "2 foo"
    assert DefunTest.c2(3, "foo")       == "3 foo"
    assert DefunTest.c2(4, "foo")       == "4 foo"
    assert DefunTest.c3({:ok, 0})       == {:ok, 0}
    assert DefunTest.d1([])             == %{}
    assert DefunTest.d2([])             == %{}
    assert DefunTest.d3(10)             == 10
    assert DefunTest.d4(10)             == 10
    assert DefunTest.d5(0, [], "")      == [0]
    assert DefunTest.d6([1], &is_nil/1) == [false]
    assert DefunTest.e1(1)              == "1 foo"
    assert DefunTest.e1(2, "bar")       == "2 bar"

    catch_error DefunTest.c2(0, "foo")
    catch_error DefunTest.c2(4, :not_a_string)
    catch_error DefunTest.c2(4, "longer_than_5_bytes")
    catch_error DefunTest.c3({:error, :reason})
  end

  test "should add typespec" do
    typespec_codes = DefunTest.typespecs
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
  end
end
