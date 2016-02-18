defmodule Croma.StructCallSyntaxTest do
  use Croma.TestCase
  import StructCallSyntax

  defmodule S do
    defstruct [field1: 0]

    def f1(_s), do: 0
    def f2(_s, i), do: i
    def f3(_s, i, j), do: i + j
  end

  test "~>/2" do
    s = %S{}
    assert s~>f1       == 0
    assert s~>f1()     == 0
    assert s~>f2(1)    == 1
    assert s~>f3(1, 2) == 3
  end
end
