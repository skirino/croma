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
    assert nilable(I).default()     == nil
  end

  test "Croma.TypeGen.list_of" do
    assert list_of(I).validate([])         == {:ok, []}
    assert list_of(I).validate([0, 1, 2])  == {:ok, [0, 1, 2]}
    assert list_of(I).validate([0, -1, 2]) == {:error, {:invalid_value, [I]}}
    assert list_of(I).validate(nil)        == {:error, {:invalid_value, [list_of(I)]}}
    assert list_of(I).default()            == []
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

  test "Croma.TypeGen.fixed" do
    assert fixed(:a).validate(:a) == {:ok, :a}
    assert fixed(1 ).validate(:a) == {:error, {:invalid_value, [fixed(1)]}}
    assert fixed(:a).default()    == :a
  end

  defmodule S do
    use Croma.Struct, fields: [i: nilable(I), l: list_of(I)]
  end

  test "struct definition with Croma.TypeGen.nilable and Croma.TypeGen.list_of" do
    s = S.new!([i: 0, l: []])
    assert s == %S{i: 0, l: []}
    assert S.new(%{                     }) == {:ok, %S{i: nil, l: []}}
    assert S.new(%{"i" => -1            }) == {:error, {:invalid_value, [S, nilable(I), I]}}
    assert S.new(%{           "l" => [] }) == {:ok, %S{i: nil, l: []}}
    assert S.new(%{"i" => -1, "l" => [] }) == {:error, {:invalid_value, [S, nilable(I), I]}}
    assert S.new(%{"i" =>  1, "l" => nil}) == {:error, {:invalid_value, [S, list_of(I)]}}

    assert S.validate(%{i: 10, l: []})         == S.update(s, [i: 10])
    assert S.validate(%{i: 0 , l: [0, 1, 2]})  == S.update(s, [l: [0, 1, 2]])
    assert S.validate(%{"i" => -1, "l" => []}) == {:error, {:invalid_value, [S, nilable(I), I]}}
    assert S.update(s, %{i: -1})               == {:error, {:invalid_value, [S, nilable(I), I]}}
    assert S.update(s, %{l: [-1]})             == {:error, {:invalid_value, [S, I]}}
  end

  test "Croma.TypeGen.nilable/1 and Croma.TypeGen.list_of/1 with underlying new/1" do
    assert nilable(S).validate(nil     ) == {:ok, nil}
    assert nilable(S).validate(%{}     ) == {:error, {:invalid_value, [nilable(S), S, list_of(I)]}}
    assert nilable(S).validate(%{l: []}) == {:ok, %S{i: nil, l: []}}
    assert nilable(S).new(nil)           == {:ok, nil}
    assert nilable(S).new(%{})           == {:ok, %S{i: nil, l: []}}

    assert list_of(S).validate([])     == {:ok, []}
    assert list_of(S).validate([%{}])  == {:error, {:invalid_value, [S, list_of(I)]}}
    assert list_of(S).new([])          == {:ok, []}
    assert list_of(S).new(:not_a_list) == {:error, {:invalid_value, [list_of(S)]}}
  end

  test "nilable and list_of for primitive types should automatically be generated" do
    assert Croma.TypeGen.Nilable.Croma.String.default() == nil
    assert Croma.TypeGen.ListOf.Croma.Map.default()     == []
  end
end
