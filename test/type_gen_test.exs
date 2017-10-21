defmodule Croma.TypeGenTest do
  use Croma.TestCase
  import TypeGen

  defmodule I do
    use Croma.SubtypeOfInt, min: 0
  end

  test "Croma.TypeGen.nilable" do
    ni = nilable(I)
    assert ni.valid?(nil)
    assert ni.valid?( 0 )
    refute ni.valid?(-1 )
    assert ni.default() == nil
  end

  test "Croma.TypeGen.list_of" do
    li = list_of(I)
    assert li.valid?([])
    assert li.valid?([0, 1, 2])
    refute li.valid?([0, -1, 2])
    refute li.valid?(nil)
    assert li.default() == []
  end

  test "Croma.TypeGen.union" do
    u1 = union([I])
    assert u1.valid?(0  )
    refute u1.valid?(nil)
    refute u1.valid?(-1 )

    u2 = union([nilable(I), list_of(I)])
    assert u2.valid?(nil )
    assert u2.valid?(0   )
    assert u2.valid?([]  )
    refute u2.valid?(-1  )
    refute u2.valid?(%{} )
    refute u2.valid?([-1])

    assert u1.new(0  ) == {:ok, 0}
    assert u1.new(nil) == {:error, {:invalid_value, [u1]}}
    assert u1.new(-1 ) == {:error, {:invalid_value, [u1]}}

    assert u2.new(nil ) == {:ok, nil}
    assert u2.new(0   ) == {:ok, 0}
    assert u2.new([]  ) == {:ok, []}
    assert u2.new(-1  ) == {:error, {:invalid_value, [u2]}}
    assert u2.new(%{} ) == {:error, {:invalid_value, [u2]}}
    assert u2.new([-1]) == {:error, {:invalid_value, [u2]}}
  end

  test "Croma.TypeGen.fixed" do
    assert fixed(:a).valid?(:a)
    refute fixed(1 ).valid?(:a)
    assert fixed(:a).default() == :a
  end

  defmodule S do
    use Croma.Struct, fields: [i: nilable(I), l: list_of(I)]
  end

  test "struct definition with Croma.TypeGen.nilable and Croma.TypeGen.list_of" do
    s = S.new!([i: 0, l: []])
    assert s == %S{i: 0, l: []}
    assert S.new(%{                     }) == {:ok, %S{i: nil, l: []}}
    assert S.new(%{"i" => -1            }) == {:error, {:invalid_value, [S, nilable(I)]}}
    assert S.new(%{           "l" => [] }) == {:ok, %S{i: nil, l: []}}
    assert S.new(%{"i" => -1, "l" => [] }) == {:error, {:invalid_value, [S, nilable(I)]}}
    assert S.new(%{"i" =>  1, "l" => nil}) == {:error, {:invalid_value, [S, list_of(I)]}}

    assert S.new(%{i: 10, l: []})         == S.update(s, [i: 10])
    assert S.new(%{i: 0 , l: [0, 1, 2]})  == S.update(s, [l: [0, 1, 2]])
    assert S.new(%{"i" => -1, "l" => []}) == {:error, {:invalid_value, [S, nilable(I)]}}
    assert S.update(s, %{i: -1})          == {:error, {:invalid_value, [S, nilable(I)]}}
    assert S.update(s, %{l: [-1]})        == {:error, {:invalid_value, [S, list_of(I)]}}
  end

  test "Croma.TypeGen.nilable/1 and Croma.TypeGen.list_of/1 with underlying new/1" do
    ns = nilable(S)
    assert ns.valid?(nil)
    refute ns.valid?(%{})
    assert ns.valid?(%S{i: nil, l: []})
    assert ns.new(nil) == {:ok, nil}
    assert ns.new(%{}) == {:ok, %S{i: nil, l: []}}

    ls = list_of(S)
    assert ls.valid?([])
    refute ls.valid?([%{}])
    assert ls.new([])          == {:ok, []}
    assert ls.new(:not_a_list) == {:error, {:invalid_value, [list_of(S)]}}
  end

  test "nilable and list_of for primitive types should automatically be generated" do
    assert Croma.TypeGen.Nilable.Croma.String.default() == nil
    assert Croma.TypeGen.ListOf.Croma.Map.default()     == []
  end
end
