defmodule Croma.StructTest do
  use ExUnit.Case

  defmodule I1 do
    use Croma.SubtypeOfInt, min: 0, max: 10
    def default, do: 0
  end
  defmodule I2 do
    use Croma.SubtypeOfInt, min: 3, max: 10
    def default, do: 5
  end

  defmodule S1 do
    use Croma.Struct, field1: I1, field2: I2

    # getter for compile-time typespec information
    type = Module.get_attribute(__MODULE__, :type) |> Macro.escape
    def type, do: unquote(type)
  end

  test "Croma.Struct" do
    assert %S1{} == %S1{field1: 0, field2: 5}
    t = S1.type |> Enum.map(fn {:type, expr, _, _} -> Macro.to_string(expr) end) |> List.first
    assert t == "t :: %Croma.StructTest.S1{field1: I1.t(), field2: I2.t()}"
  end
end
