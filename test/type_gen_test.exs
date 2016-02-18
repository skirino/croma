defmodule Croma.TypeGenTest do
  use Croma.TestCase
  import TypeGen

  defmodule I do
    use Croma.SubtypeOfInt, min: 0
  end

  test "Croma.TypeGen.nilable" do
    assert nilable(I).validate(nil) == {:ok, nil}
    assert nilable(I).validate( 0 ) == {:ok, 0}
    assert nilable(I).validate(-1 ) == {:error, {:invalid_value, [nilable(I), I]}}
  end

  test "Croma.TypeGen.list_of" do
    assert list_of(I).validate([])         == {:ok, []}
    assert list_of(I).validate([0, 1, 2])  == {:ok, [0, 1, 2]}
    assert list_of(I).validate([0, -1, 2]) == {:error, {:invalid_value, [I]}}
    assert list_of(I).validate(nil)        == {:error, {:invalid_value, [list_of(I)]}}
  end

  test "Croma.TypeGen.union" do
    assert union([I]).validate(0  ) == {:ok, 0}
    assert union([I]).validate(nil) == {:error, {:invalid_value, [union([I])]}}
    assert union([I]).validate(-1 ) == {:error, {:invalid_value, [union([I])]}}

    assert union([nilable(I), list_of(I)]).validate(nil ) == {:ok, nil}
    assert union([nilable(I), list_of(I)]).validate(0   ) == {:ok, 0}
    assert union([nilable(I), list_of(I)]).validate([]  ) == {:ok, []}
    assert union([nilable(I), list_of(I)]).validate(-1  ) == {:error, {:invalid_value, [union([nilable(I), list_of(I)])]}}
    assert union([nilable(I), list_of(I)]).validate(%{} ) == {:error, {:invalid_value, [union([nilable(I), list_of(I)])]}}
    assert union([nilable(I), list_of(I)]).validate([-1]) == {:error, {:invalid_value, [union([nilable(I), list_of(I)])]}}
  end

  defmodule S do
    use Croma.Struct, fields: [i: nilable(I), l: list_of(I)]
  end

  test "struct definition with Croma.TypeGen.nilable and Croma.TypeGen.list_of" do
    s = S.new!([i: 0, l: []])
    assert s == %S{i: 0, l: []}

    assert S.new(%{"i" => -1            }) == {:error, {:invalid_value, [S, nilable(I), I]}}
    assert S.new(%{           "l" => [] }) == {:error, {:value_missing, [S, nilable(I)]}}
    assert S.new(%{"i" => -1, "l" => [] }) == {:error, {:invalid_value, [S, nilable(I), I]}}
    assert S.new(%{"i" =>  1, "l" => nil}) == {:error, {:invalid_value, [S, list_of(I)]}}

    assert S.validate(%{i: 10, l: []})         == S.update(s, [i: 10])
    assert S.validate(%{i: 0 , l: [0, 1, 2]})  == S.update(s, [l: [0, 1, 2]])
    assert S.validate(%{"i" => -1, "l" => []}) == {:error, {:invalid_value, [S, nilable(I), I]}}
    assert S.update(s, %{i: -1})               == {:error, {:invalid_value, [S, nilable(I), I]}}
    assert S.update(s, %{l: [-1]})             == {:error, {:invalid_value, [S, I]}}
  end
end
