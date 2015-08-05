defmodule Croma.TypeTest do
  use ExUnit.Case
  import Croma.TypeGen

  defmodule I do
    use Croma.SubtypeOfInt, min: 0
  end

  test "Croma.TypeGen.nilable" do
    assert nilable(I).validate(nil) == {:ok, nil}
    assert nilable(I).validate( 0 ) == {:ok, 0}
    assert nilable(I).validate(-1 ) == {:error, "validation error for #{I}: -1"}
  end

  test "Croma.TypeGen.list_of" do
    assert list_of(I).validate([])         == {:ok, []}
    assert list_of(I).validate([0, 1, 2])  == {:ok, [0, 1, 2]}
    assert list_of(I).validate([0, -1, 2]) == {:error, "validation error for #{I}: -1"}
    assert list_of(I).validate(nil)        == {:error, "validation error for #{list_of(I)}: nil"}
  end

  defmodule S do
    use Croma.Struct, i: nilable(I), l: list_of(I)
  end

  test "struct definition with Croma.TypeGen.nilable" do
    s = S.new([i: 0, l: []])
    assert s == %S{i: 0, l: []}

    catch_error S.new(%{"i" => -1            })
    catch_error S.new(%{           "l" => [] })
    catch_error S.new(%{"i" => -1, "l" => [] })
    catch_error S.new(%{"i" =>  1, "l" => nil})

    assert S.validate(%{i: 10, l: []})         == S.update(s, [i: 10])
    assert S.validate(%{i: 0 , l: [0, 1, 2]})  == S.update(s, [l: [0, 1, 2]])
    assert S.validate(%{"i" => -1, "l" => []}) == {:error, "validation error for #{I}: -1"}
    assert S.update(s, %{i: -1})               == {:error, "validation error for #{I}: -1"}
    assert S.update(s, %{l: [-1]})             == {:error, "validation error for #{I}: -1"}
  end
end