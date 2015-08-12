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

  test "Croma.Struct: construct" do
    assert %S1{} == %S1{field1: 0, field2: nil}
    t = S1.type |> Enum.map(fn {:type, expr, _, _} -> Macro.to_string(expr) end) |> List.first
    assert t == "t :: %Croma.StructTest.S1{field1: Croma.StructTest.I1.t(), field2: Croma.Boolean.t()}"
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
    assert S1.new( [                 field2:    true ]) == %S1{field1: 0, field2: true }
    assert S1.new(%{                 field2:    false}) == %S1{field1: 0, field2: false}
    assert S1.new(%{                "field2" => true }) == %S1{field1: 0, field2: true }
    assert S1.new( [ field1:     2,  field2:    false]) == %S1{field1: 2, field2: false}
    assert S1.new(%{ field1:     2,  field2:    true }) == %S1{field1: 2, field2: true }
    assert S1.new(%{"field1" =>  2, "field2" => false}) == %S1{field1: 2, field2: false}
  end

  test "Croma.Struct: validate/1" do
    assert S1.validate( [                                 ]) == {:error, "validation error for Elixir.Croma.StructTest.I1: nil"}
    assert S1.validate(%{                                 }) == {:error, "validation error for Elixir.Croma.StructTest.I1: nil"}
    assert S1.validate( [ field1:    2                    ]) == {:error, {:invalid_value, [Croma.Boolean]}}
    assert S1.validate(%{"field1" => 2                    }) == {:error, {:invalid_value, [Croma.Boolean]}}
    assert S1.validate( [                 field2:    true ]) == {:error, "validation error for Elixir.Croma.StructTest.I1: nil"}
    assert S1.validate(%{                "field2" => false}) == {:error, "validation error for Elixir.Croma.StructTest.I1: nil"}
    assert S1.validate( [ field1:    -1,  field2:    true ]) == {:error, "validation error for Elixir.Croma.StructTest.I1: -1"}
    assert S1.validate(%{"field1" => -1, "field2" => false}) == {:error, "validation error for Elixir.Croma.StructTest.I1: -1"}
    assert S1.validate( [ field1:     1,  field2:    0    ]) == {:error, {:invalid_value, [Croma.Boolean]}}
    assert S1.validate(%{"field1" =>  1, "field2" => 0    }) == {:error, {:invalid_value, [Croma.Boolean]}}
    assert S1.validate( [ field1:     1,  field2:    true ]) == {:ok   , %S1{field1: 1, field2: true }}
    assert S1.validate(%{"field1" =>  1, "field2" => false}) == {:ok   , %S1{field1: 1, field2: false}}

    assert S1.validate(nil) == {:error, "validation error for Elixir.Croma.StructTest.S1: nil"}
    assert S1.validate("" ) == {:error, "validation error for Elixir.Croma.StructTest.S1: \"\""}
  end

  test "Croma.Struct: update/2" do
    s = S1.new(field1: 1, field2: false)

    assert S1.update(s,  [ field1:    2                  ]) == {:ok, %S1{field1: 2, field2: false}}
    assert S1.update(s, %{"field1" => 2                  }) == {:ok, %S1{field1: 2, field2: false}}
    assert S1.update(s,  [                field2:    true]) == {:ok, %S1{field1: 1, field2: true }}
    assert S1.update(s, %{               "field2" => true}) == {:ok, %S1{field1: 1, field2: true }}
    assert S1.update(s,  [ field1:    2,  field2:    true]) == {:ok, %S1{field1: 2, field2: true }}
    assert S1.update(s, %{"field1" => 2, "field2" => true}) == {:ok, %S1{field1: 2, field2: true }}

    assert S1.update(s,  [ field1:    -1,                ]) == {:error, "validation error for #{I1}: -1"}
    assert S1.update(s, %{"field1" => -1,                }) == {:error, "validation error for #{I1}: -1"}
    assert S1.update(s,  [                 field2:    0  ]) == {:error, {:invalid_value, [Croma.Boolean]}}
    assert S1.update(s, %{                "field2" => nil}) == {:error, {:invalid_value, [Croma.Boolean]}}
    assert S1.update(s,  [ field1:    -1,  field2:    0  ]) == {:error, "validation error for #{I1}: -1"}
    assert S1.update(s, %{"field1" => -1, "field2" => nil}) == {:error, "validation error for #{I1}: -1"}

    assert S1.update(s, [nonexisting: 0]) == {:ok, s}

    # reject different type of struct
    catch_error S1.update(%{}, %{})
    catch_error S1.update(%Regex{}, %{})
  end
end
