defmodule Croma.StructTest do
  use ExUnit.Case

  defmodule EmptyStructShouldBeSuccessfullyCompiled do
    use Croma.Struct, []
  end

  defmodule I1 do
    use Croma.SubtypeOfInt, min: 0, max: 10, default: 0
  end

  defmodule S1 do
    use Croma.Struct, field1: I1, field2: Croma.Boolean

    # getter for compile-time typespec information
    type = Module.get_attribute(__MODULE__, :type) |> Macro.escape
    def type, do: unquote(type)
  end

  test "Croma.Struct: new/1" do
    assert S1.new( []                             ) == {:error, {:value_missing, [S1, Croma.Boolean]}}
    assert S1.new(%{}                             ) == {:error, {:value_missing, [S1, Croma.Boolean]}}
    assert S1.new( [ field1:    2]                ) == {:error, {:value_missing, [S1, Croma.Boolean]}}
    assert S1.new(%{ field1:    2}                ) == {:error, {:value_missing, [S1, Croma.Boolean]}}
    assert S1.new(%{"field1" => 2}                ) == {:error, {:value_missing, [S1, Croma.Boolean]}}
    assert S1.new( [                 field2:    2]) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.new(%{                 field2:    2}) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.new(%{                "field2" => 2}) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.new( [ field1:    -1,  field2:    2]) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.new(%{ field1:    -1,  field2:    2}) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.new(%{"field1" => -1, "field2" => 2}) == {:error, {:invalid_value, [S1, I1]}}

    assert S1.new( [                 field2:    true ]) == {:ok, %S1{field1: 0, field2: true }}
    assert S1.new(%{                 field2:    false}) == {:ok, %S1{field1: 0, field2: false}}
    assert S1.new(%{                "field2" => true }) == {:ok, %S1{field1: 0, field2: true }}
    assert S1.new( [ field1:     2,  field2:    false]) == {:ok, %S1{field1: 2, field2: false}}
    assert S1.new(%{ field1:     2,  field2:    true }) == {:ok, %S1{field1: 2, field2: true }}
    assert S1.new(%{"field1" =>  2, "field2" => false}) == {:ok, %S1{field1: 2, field2: false}}

    assert S1.new!([field2: true]) == %S1{field1: 0, field2: true}
    catch_error S1.new!([])
  end

  test "Croma.Struct: validate/1" do
    assert S1.validate( [                                 ]) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.validate(%{                                 }) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.validate( [ field1:    2                    ]) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.validate(%{"field1" => 2                    }) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.validate( [                 field2:    true ]) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.validate(%{                "field2" => false}) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.validate( [ field1:    -1,  field2:    true ]) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.validate(%{"field1" => -1, "field2" => false}) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.validate( [ field1:     1,  field2:    0    ]) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.validate(%{"field1" =>  1, "field2" => 0    }) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.validate( [ field1:     1,  field2:    true ]) == {:ok   , %S1{field1: 1, field2: true }}
    assert S1.validate(%{"field1" =>  1, "field2" => false}) == {:ok   , %S1{field1: 1, field2: false}}

    assert S1.validate(nil) == {:error, {:invalid_value, [S1]}}
    assert S1.validate("" ) == {:error, {:invalid_value, [S1]}}

    # struct itself should be valid
    s = S1.new!(field2: false)
    assert S1.validate(s) == {:ok, s}

    assert S1.validate!([field1: 1, field2: true]) == %S1{field1: 1, field2: true}
    catch_error S1.validate!([])
  end

  test "Croma.Struct: update/2" do
    s = S1.new!(field1: 1, field2: false)

    assert S1.update(s,  [ field1:    2                  ]) == {:ok, %S1{field1: 2, field2: false}}
    assert S1.update(s, %{"field1" => 2                  }) == {:ok, %S1{field1: 2, field2: false}}
    assert S1.update(s,  [                field2:    true]) == {:ok, %S1{field1: 1, field2: true }}
    assert S1.update(s, %{               "field2" => true}) == {:ok, %S1{field1: 1, field2: true }}
    assert S1.update(s,  [ field1:    2,  field2:    true]) == {:ok, %S1{field1: 2, field2: true }}
    assert S1.update(s, %{"field1" => 2, "field2" => true}) == {:ok, %S1{field1: 2, field2: true }}

    assert S1.update(s,  [ field1:    -1,                ]) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.update(s, %{"field1" => -1,                }) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.update(s,  [                 field2:    0  ]) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.update(s, %{                "field2" => nil}) == {:error, {:invalid_value, [S1, Croma.Boolean]}}
    assert S1.update(s,  [ field1:    -1,  field2:    0  ]) == {:error, {:invalid_value, [S1, I1]}}
    assert S1.update(s, %{"field1" => -1, "field2" => nil}) == {:error, {:invalid_value, [S1, I1]}}

    assert S1.update(s, [nonexisting: 0]) == {:ok, s}

    # reject different type of struct
    catch_error S1.update(%{}, %{})
    catch_error S1.update(%Regex{}, %{})
  end
end
