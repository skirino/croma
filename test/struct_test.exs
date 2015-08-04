defmodule Croma.StructTest do
  use ExUnit.Case

  defmodule I1 do
    use Croma.SubtypeOfInt, min: 0, max: 10, default: 0
  end
  defmodule I2 do
    use Croma.SubtypeOfInt, min: 3, max: 10
  end

  defmodule S1 do
    use Croma.Struct, field1: I1, field2: I2

    # getter for compile-time typespec information
    type = Module.get_attribute(__MODULE__, :type) |> Macro.escape
    def type, do: unquote(type)
  end

  test "Croma.Struct: construct" do
    assert %S1{} == %S1{field1: 0, field2: nil}
    t = S1.type |> Enum.map(fn {:type, expr, _, _} -> Macro.to_string(expr) end) |> List.first
    assert t == "t :: %Croma.StructTest.S1{field1: I1.t(), field2: I2.t()}"
  end

  test "Croma.Struct: new/1" do
    catch_error S1.new( [])
    catch_error S1.new(%{})
    catch_error S1.new( [ field1:    2])
    catch_error S1.new(%{ field1:    2})
    catch_error S1.new(%{"field1" => 2})
    catch_error S1.new( [                 field2:    2])
    catch_error S1.new(%{                 field2:    2})
    catch_error S1.new(%{                "field2" => 2})
    catch_error S1.new( [ field1:    -1,  field2:    2])
    catch_error S1.new(%{ field1:    -1,  field2:    2})
    catch_error S1.new(%{"field1" => -1, "field2" => 2})
    assert S1.new( [                 field2:    5]) == %S1{field1: 0, field2: 5}
    assert S1.new(%{                 field2:    5}) == %S1{field1: 0, field2: 5}
    assert S1.new(%{                "field2" => 5}) == %S1{field1: 0, field2: 5}
    assert S1.new( [ field1:     2,  field2:    5]) == %S1{field1: 2, field2: 5}
    assert S1.new(%{ field1:     2,  field2:    5}) == %S1{field1: 2, field2: 5}
    assert S1.new(%{"field1" =>  2, "field2" => 5}) == %S1{field1: 2, field2: 5}
  end

  test "Croma.Struct: validate/1" do
    assert S1.validate( [                             ]) == {:error, "validation error for #{I1}: nil"}
    assert S1.validate(%{                             }) == {:error, "validation error for #{I1}: nil"}
    assert S1.validate( [ field1:    2                ]) == {:error, "validation error for #{I2}: nil"}
    assert S1.validate(%{"field1" => 2                }) == {:error, "validation error for #{I2}: nil"}
    assert S1.validate( [                 field2:    5]) == {:error, "validation error for #{I1}: nil"}
    assert S1.validate(%{                "field2" => 5}) == {:error, "validation error for #{I1}: nil"}
    assert S1.validate( [ field1:    -1,  field2:    5]) == {:error, "validation error for #{I1}: -1"}
    assert S1.validate(%{"field1" => -1, "field2" => 5}) == {:error, "validation error for #{I1}: -1"}
    assert S1.validate( [ field1:     1,  field2:    2]) == {:error, "validation error for #{I2}: 2"}
    assert S1.validate(%{"field1" =>  1, "field2" => 2}) == {:error, "validation error for #{I2}: 2"}
    assert S1.validate( [ field1:     1,  field2:    5]) == {:ok   , %S1{field1: 1, field2: 5}}
    assert S1.validate(%{"field1" =>  1, "field2" => 5}) == {:ok   , %S1{field1: 1, field2: 5}}

    assert S1.validate(nil) == {:error, "validation error for #{S1}: nil"}
    assert S1.validate("" ) == {:error, "validation error for #{S1}: \"\""}
  end
end
