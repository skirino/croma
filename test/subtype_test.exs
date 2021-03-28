defmodule Croma.SubtypeTest do
  use ExUnit.Case

  defmodule I1 do
    use Croma.SubtypeOfInt, min: 1
  end
  defmodule I2 do
    use Croma.SubtypeOfInt, min: 0, max: 10
  end
  defmodule I3 do
    use Croma.SubtypeOfInt, max: -1, default: -5
  end
  defmodule I4 do
    use Croma.SubtypeOfInt, min: -5, max: 5, default: 0
  end

  test "Croma.SubtypeOfInt: valid?/1" do
    refute I1.valid?(0)
    assert I1.valid?(1)

    refute I2.valid?(-1)
    assert I2.valid?( 0)
    assert I2.valid?(10)
    refute I2.valid?(11)

    assert I3.valid?(-1)
    refute I3.valid?( 0)

    refute I4.valid?(-6)
    assert I4.valid?(-5)
    assert I4.valid?( 5)
    refute I4.valid?( 6)

    refute I1.valid?(nil)
    refute I1.valid?([] )
  end

  test "Croma.SubtypeOfInt: default/0" do
    catch_error I1.default()
    catch_error I2.default()
    assert      I3.default() == -5
    assert      I4.default() ==  0

    assert      I1.min() == 1
    catch_error I1.max()
    assert      I2.min() == 0
    assert      I2.max() == 10
    catch_error I3.min()
    assert      I3.max() == -1
    assert      I4.min() == -5
    assert      I4.max() == 5
  end

  defmodule F1 do
    use Croma.SubtypeOfFloat, min: -5.0
  end
  defmodule F2 do
    use Croma.SubtypeOfFloat, max: 10.0, default: 1.0
  end
  defmodule F3 do
    use Croma.SubtypeOfFloat, min: 0.0, max: 1.5, default: 0.5
  end

  test "Croma.SubtypeOfFloat: valid?/1" do
    refute F1.valid?(-5.1)
    assert F1.valid?(-5.0)

    assert F2.valid?(10.0)
    refute F2.valid?(10.1)

    refute F3.valid?(-0.1)
    assert F3.valid?( 0.0)
    assert F3.valid?( 1.5)
    refute F3.valid?( 1.6)

    refute F1.valid?(nil)
    refute F1.valid?(0  )
    refute F1.valid?([] )
  end

  test "Croma.SubtypeOfFloat: default/0" do
    catch_error F1.default()
    assert      F2.default() == 1.0
    assert      F3.default() == 0.5

    assert      F1.min() == -5.0
    catch_error F1.max()
    catch_error F2.min()
    assert      F2.max() == 10.0
    assert      F3.min() == 0.0
    assert      F3.max() == 1.5
  end

  defmodule N1 do
    use Croma.SubtypeOfNumber, min: -5.0
  end
  defmodule N2 do
    use Croma.SubtypeOfNumber, max: 10.0, default: 1
  end
  defmodule N3 do
    use Croma.SubtypeOfNumber, min: 0.0, max: 1.5, default: 0.5
  end

  test "Croma.SubtypeOfNumber: valid?/1" do
    refute N1.valid?(-5.1)
    assert N1.valid?(-5.0)
    assert N1.valid?(-5  )

    assert N2.valid?(10  )
    assert N2.valid?(10.0)
    refute N2.valid?(10.1)

    refute N3.valid?(-0.1)
    assert N3.valid?( 0  )
    assert N3.valid?( 0.0)
    assert N3.valid?( 1.5)
    refute N3.valid?( 1.6)

    assert N1.valid?( 0  )
    refute N1.valid?(nil)
    refute N1.valid?([] )
  end

  test "Croma.SubtypeOfNumber: default/0" do
    catch_error N1.default()
    assert      N2.default() == 1
    assert      N3.default() == 0.5

    assert      N1.min() == -5.0
    catch_error N1.max()
    catch_error N2.min()
    assert      N2.max() == 10.0
    assert      N3.min() == 0.0
    assert      N3.max() == 1.5
  end

  defmodule S1 do
    use Croma.SubtypeOfString, pattern: ~r/^foo|bar$/, default: "foo"
  end

  test "Croma.SubtypeOfString: valid?/1" do
    assert S1.valid?("foo")
    assert S1.valid?("bar")
    refute S1.valid?("baz")
    refute S1.valid?(nil)
    refute S1.valid?([])
  end

  test "Croma.SubtypeOfString: default/0" do
    assert S1.default() == "foo"
    assert S1.pattern() == ~r/^foo|bar$/
  end

  defmodule A1 do
    use Croma.SubtypeOfAtom, values: [:a1, :a2, :a3], default: :a1
  end

  test "Croma.SubtypeOfAtom: valid?/1" do
    assert A1.valid?(:a1)
    assert A1.valid?(:a2)
    assert A1.valid?(:a3)
    refute A1.valid?(:a4)
    refute A1.valid?(nil)
    refute A1.valid?([])
  end

  test "Croma.SubtypeOfAtom: new/1" do
    assert A1.new("a1") == {:ok, :a1}
    assert A1.new("a2") == {:ok, :a2}
    assert A1.new("a3") == {:ok, :a3}
    assert A1.new("a4") == {:error, {:invalid_value, [A1]}}

    assert      A1.new!("a1") == :a1
    assert      A1.new!("a2") == :a2
    assert      A1.new!("a3") == :a3
    catch_error A1.new!("a4")
  end

  test "Croma.SubtypeOfAtom: default/0" do
    assert A1.default() == :a1
    assert A1.values()  == [:a1, :a2, :a3]
  end

  defmodule L1 do
    use Croma.SubtypeOfList, elem_module: I1, default: []
  end
  defmodule L2 do
    use Croma.SubtypeOfList, elem_module: I2, max_length: 3, default: [0, 0, 0]
  end
  defmodule L3 do
    use Croma.SubtypeOfList, elem_module: I3, min_length: 2
  end
  defmodule L4 do
    use Croma.SubtypeOfList, elem_module: I4, min_length: 1, max_length: 3
  end
  defmodule L5 do
    use Croma.SubtypeOfList, elem_module: A1, min_length: 1
  end

  test "Croma.SubtypeOfList: valid?/1" do
    assert L1.valid?([])
    assert L1.valid?([1])
    refute L1.valid?([0])

    assert L2.valid?([])
    assert L2.valid?([1, 2, 3])
    refute L2.valid?([1, 2, 11])
    refute L2.valid?([1, 2, 3, 4])

    refute L3.valid?([ 1])
    refute L3.valid?([-1])
    assert L3.valid?([-1, -2])

    refute L4.valid?([])
    assert L4.valid?([-5])
    assert L4.valid?([-5, 0, 5])
    refute L4.valid?([-5, 10])
    refute L4.valid?([0, 0, 0, 0])
  end

  test "Croma.SubtypeOfList: new/1" do
    assert L5.new([])          == {:error, {:invalid_value, [L5]}}
    assert L5.new([:a1, :a2])  == {:ok, [:a1, :a2]}
    assert L5.new([:a1, "a3"]) == {:ok, [:a1, :a3]}
    assert L5.new([:a1, :a4])  == {:error, {:invalid_value, [L5, A1]}}

    catch_error L5.new!([])
    assert      L5.new!([:a1, :a2])  == [:a1, :a2]
    assert      L5.new!([:a1, "a3"]) == [:a1, :a3]
    catch_error L5.new!([:a1, :a4])
  end

  test "Croma.SubtypeOfList: default/0" do
    assert      L1.default() == []
    assert      L2.default() == [0, 0, 0]
    catch_error L3.default()
    catch_error L4.default()

    catch_error L1.min_length()
    catch_error L1.max_length()
    catch_error L2.min_length()
    assert      L2.max_length() == 3
    assert      L3.min_length() == 2
    catch_error L3.max_length()
    assert      L4.min_length() == 1
    assert      L4.max_length() == 3
  end

  defmodule M1 do
    use Croma.SubtypeOfMap, key_module: A1, value_module: I1, default: %{}
  end
  defmodule M2 do
    use Croma.SubtypeOfMap, key_module: A1, value_module: I2, min_size: 1, default: %{a1: 0}
  end
  defmodule M3 do
    use Croma.SubtypeOfMap, key_module: A1, value_module: I3, max_size: 2
  end
  defmodule M4 do
    use Croma.SubtypeOfMap, key_module: A1, value_module: I4, min_size: 1, max_size: 2
  end

  test "Croma.SubtypeOfMap: valid?/1" do
    assert M1.valid?(%{})
    assert M1.valid?(%{a1: 1})
    assert M1.valid?(%{a1: 1, a2: 2, a3: 3})
    refute M1.valid?(%{a: 1})
    refute M1.valid?(%{a1: 0})

    refute M2.valid?(%{})
    assert M2.valid?(%{a1: 1})
    assert M2.valid?(%{a1: 1, a2: 2, a3: 3})
    refute M2.valid?(%{a: 1})
    refute M2.valid?(%{a1: -1})

    assert M3.valid?(%{})
    assert M3.valid?(%{a1: -1})
    refute M3.valid?(%{a1: 1, a2: 2, a3: 3})
    refute M3.valid?(%{a: 1})
    refute M3.valid?(%{a1: "not_int"})

    refute M4.valid?(%{})
    assert M4.valid?(%{a1: -1})
    refute M4.valid?(%{a1: 1, a2: 2, a3: 3})
    refute M4.valid?(%{a: 1})
    refute M4.valid?(%{a1: "not_int"})
  end

  test "Croma.SubtypeOfMap: new/1" do
    assert M1.new(%{"a1" =>  1})    == {:ok, %{a1:  1}}
    assert M1.new(%{a1: 0})         == {:error, {:invalid_value, [M1, I1]}}
    assert M2.new(%{"a1" =>  1})    == {:ok, %{a1:  1}}
    assert M2.new(%{"a4" => -1})    == {:error, {:invalid_value, [M2, A1]}}
    assert M3.new(%{"a1" => -1})    == {:ok, %{a1: -1}}
    assert M3.new(%{a1: "not_int"}) == {:error, {:invalid_value, [M3, I3]}}
    assert M4.new(%{"a1" => -1})    == {:ok, %{a1: -1}}
    assert M4.new(%{a4: "not_int"}) == {:error, {:invalid_value, [M4, A1]}}

    assert      M1.new!(%{"a1" =>  1}) == %{a1:  1}
    catch_error M1.new!(%{a1: 0})
    assert      M2.new!(%{"a1" =>  1}) == %{a1:  1}
    catch_error M2.new!(%{"a4" => -1})
    assert      M3.new!(%{"a1" => -1}) == %{a1: -1}
    catch_error M3.new!(%{a1: "not_int"})
    assert      M4.new!(%{"a1" => -1}) == %{a1: -1}
    catch_error M4.new!(%{a4: "not_int"})
  end

  test "Croma.SubtypeOfMap: default/0" do
    assert      M1.default() == %{}
    assert      M2.default() == %{a1: 0}
    catch_error M3.default()
    catch_error M4.default()

    catch_error M1.min_size()
    catch_error M1.max_size()
    assert      M2.min_size() == 1
    catch_error M2.max_size()
    catch_error M3.min_size()
    assert      M3.max_size() == 2
    assert      M4.min_size() == 1
    assert      M4.max_size() == 2
  end

  defmodule T0 do
    use Croma.SubtypeOfTuple, elem_modules: [], default: {}
  end
  defmodule T1 do
    use Croma.SubtypeOfTuple, elem_modules: [A1]
  end
  defmodule T3 do
    use Croma.SubtypeOfTuple, elem_modules: [I1, S1, L1]
  end

  test "Croma.SubtypeOfTuple: valid?/1" do
    refute T0.valid?(nil)
    assert T0.valid?({})

    refute T1.valid?({})
    refute T1.valid?({:a})
    assert T1.valid?({:a1})

    refute T3.valid?({})
    refute T3.valid?({1, "", []})
    assert T3.valid?({1, "foo", []})
  end

  test "Croma.SubtypeOfTuple: new/1" do
    assert T1.new({:a1})  == {:ok, {:a1}}
    assert T1.new({"a1"}) == {:ok, {:a1}}
    assert T1.new({"a4"}) == {:error, {:invalid_value, [T1, A1]}}

    assert      T1.new!({:a1})  == {:a1}
    assert      T1.new!({"a1"}) == {:a1}
    catch_error T1.new!({"a4"})
  end

  test "Croma.SubtypeOfTuple: default/0" do
    assert      T0.default() == {}
    catch_error T1.default()
    catch_error T3.default()
  end
end
