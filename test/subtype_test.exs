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

  test "Croma.SubtypeOfInt: validate/1" do
    assert I1.validate(0) == {:error, {:invalid_value, [I1]}}
    assert I1.validate(1) == {:ok   , 1}

    assert I2.validate(-1) == {:error, {:invalid_value, [I2]}}
    assert I2.validate( 0) == {:ok   ,  0}
    assert I2.validate(10) == {:ok   , 10}
    assert I2.validate(11) == {:error, {:invalid_value, [I2]}}

    assert I3.validate(-1) == {:ok   , -1}
    assert I3.validate( 0) == {:error, {:invalid_value, [I3]}}

    assert I4.validate(-6) == {:error, {:invalid_value, [I4]}}
    assert I4.validate(-5) == {:ok   , -5}
    assert I4.validate( 5) == {:ok   ,  5}
    assert I4.validate( 6) == {:error, {:invalid_value, [I4]}}

    assert I1.validate(nil) == {:error, {:invalid_value, [I1]}}
    assert I1.validate([] ) == {:error, {:invalid_value, [I1]}}
  end

  test "Croma.SubtypeOfInt: default/0" do
    catch_error I1.default
    catch_error I2.default
    assert      I3.default == -5
    assert      I4.default ==  0

    assert      I1.min == 1
    catch_error I1.max
    assert      I2.min == 0
    assert      I2.max == 10
    catch_error I3.min
    assert      I3.max == -1
    assert      I4.min == -5
    assert      I4.max == 5
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

  test "Croma.SubtypeOfFloat: validate/1" do
    assert F1.validate(-5.1) == {:error, {:invalid_value, [F1]}}
    assert F1.validate(-5.0) == {:ok   , -5.0}

    assert F2.validate(10.0) == {:ok   , 10.0}
    assert F2.validate(10.1) == {:error, {:invalid_value, [F2]}}

    assert F3.validate(-0.1) == {:error, {:invalid_value, [F3]}}
    assert F3.validate( 0.0) == {:ok   , 0.0}
    assert F3.validate( 1.5) == {:ok   , 1.5}
    assert F3.validate( 1.6) == {:error, {:invalid_value, [F3]}}

    assert F1.validate(nil) == {:error, {:invalid_value, [F1]}}
    assert F1.validate([] ) == {:error, {:invalid_value, [F1]}}
  end

  test "Croma.SubtypeOfFloat: default/0" do
    catch_error F1.default
    assert      F2.default == 1.0
    assert      F3.default == 0.5

    assert      F1.min == -5.0
    catch_error F1.max
    catch_error F2.min
    assert      F2.max == 10.0
    assert      F3.min == 0.0
    assert      F3.max == 1.5
  end

  defmodule S1 do
    use Croma.SubtypeOfString, pattern: ~r/^foo|bar$/, default: "foo"
  end

  test "Croma.SubtypeOfString: validate/1" do
    assert S1.validate("foo") == {:ok   , "foo"}
    assert S1.validate("bar") == {:ok   , "bar"}
    assert S1.validate("buz") == {:error, {:invalid_value, [S1]}}
    assert S1.validate(nil  ) == {:error, {:invalid_value, [S1]}}
    assert S1.validate([]   ) == {:error, {:invalid_value, [S1]}}
  end

  test "Croma.SubtypeOfString: default/0" do
    assert S1.default == "foo"
    assert S1.pattern == ~r/^foo|bar$/
  end

  defmodule A1 do
    use Croma.SubtypeOfAtom, values: [:a1, :a2, :a3], default: :a1
  end

  test "Croma.SubtypeOfAtom: validate/1" do
    assert A1.validate(:a1 ) == {:ok   , :a1}
    assert A1.validate("a1") == {:ok   , :a1}
    assert A1.validate(:a2 ) == {:ok   , :a2}
    assert A1.validate("a2") == {:ok   , :a2}
    assert A1.validate(:a3 ) == {:ok   , :a3}
    assert A1.validate("a3") == {:ok   , :a3}
    assert A1.validate(:a4 ) == {:error, {:invalid_value, [A1]}}
    assert A1.validate("a4") == {:error, {:invalid_value, [A1]}}
    assert A1.validate(nil ) == {:error, {:invalid_value, [A1]}}
    assert A1.validate([]  ) == {:error, {:invalid_value, [A1]}}
  end

  test "Croma.SubtypeOfAtom: default/0" do
    assert A1.default == :a1
    assert A1.values  == [:a1, :a2, :a3]
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

  test "Croma.SubtypeOfList: validate/1" do
    assert L1.validate([] ) == {:ok   , []}
    assert L1.validate([1]) == {:ok   , [1]}
    assert L1.validate([0]) == {:error, {:invalid_value, [L1, I1]}}

    assert L2.validate([]          ) == {:ok   , []}
    assert L2.validate([1, 2, 3]   ) == {:ok   , [1, 2, 3]}
    assert L2.validate([1, 2, 11]  ) == {:error, {:invalid_value, [L2, I2]}}
    assert L2.validate([1, 2, 3, 4]) == {:error, {:invalid_value, [L2]}}

    assert L3.validate([ 1]    ) == {:error, {:invalid_value, [L3, I3]}}
    assert L3.validate([-1]    ) == {:error, {:invalid_value, [L3]}}
    assert L3.validate([-1, -2]) == {:ok   , [-1, -2]}

    assert L4.validate([]          ) == {:error, {:invalid_value, [L4]}}
    assert L4.validate([-5]        ) == {:ok   , [-5]}
    assert L4.validate([-5, 0, 5]  ) == {:ok   , [-5, 0, 5]}
    assert L4.validate([-5, 10]    ) == {:error, {:invalid_value, [L4, I4]}}
    assert L4.validate([0, 0, 0, 0]) == {:error, {:invalid_value, [L4]}}
  end

  test "Croma.SubtypeOfList: default/0" do
    assert      L1.default == []
    assert      L2.default == [0, 0, 0]
    catch_error L3.default
    catch_error L4.default

    catch_error L1.min_length
    catch_error L1.max_length
    catch_error L2.min_length
    assert      L2.max_length == 3
    assert      L3.min_length == 2
    catch_error L3.max_length
    assert      L4.min_length == 1
    assert      L4.max_length == 3
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

  test "Croma.SubtypeOfMap: validate/1" do
    assert M1.validate(%{})                    == {:ok, %{}}
    assert M1.validate(%{"a1" => 1})           == {:ok, %{a1: 1}}
    assert M1.validate(%{a1: 1, a2: 2, a3: 3}) == {:ok, %{a1: 1, a2: 2, a3: 3}}
    assert M1.validate(%{a: 1})                == {:error, {:invalid_value, [M1, A1]}}
    assert M1.validate(%{a1: 0})               == {:error, {:invalid_value, [M1, I1]}}

    assert M2.validate(%{})                    == {:error, {:invalid_value, [M2]}}
    assert M2.validate(%{"a1" => 1})           == {:ok, %{a1: 1}}
    assert M2.validate(%{a1: 1, a2: 2, a3: 3}) == {:ok, %{a1: 1, a2: 2, a3: 3}}
    assert M2.validate(%{a: 1})                == {:error, {:invalid_value, [M2, A1]}}
    assert M2.validate(%{a1: -1})              == {:error, {:invalid_value, [M2, I2]}}

    assert M3.validate(%{})                    == {:ok, %{}}
    assert M3.validate(%{"a1" => -1})          == {:ok, %{a1: -1}}
    assert M3.validate(%{a1: 1, a2: 2, a3: 3}) == {:error, {:invalid_value, [M3]}}
    assert M3.validate(%{a: 1})                == {:error, {:invalid_value, [M3, A1]}}
    assert M3.validate(%{a1: "not_int"})       == {:error, {:invalid_value, [M3, I3]}}

    assert M4.validate(%{})                    == {:error, {:invalid_value, [M4]}}
    assert M4.validate(%{"a1" => -1})          == {:ok, %{a1: -1}}
    assert M4.validate(%{a1: 1, a2: 2, a3: 3}) == {:error, {:invalid_value, [M4]}}
    assert M4.validate(%{a: 1})                == {:error, {:invalid_value, [M4, A1]}}
    assert M4.validate(%{a1: "not_int"})       == {:error, {:invalid_value, [M4, I4]}}
  end

  test "Croma.SubtypeOfMap: default/0" do
    assert      M1.default == %{}
    assert      M2.default == %{a1: 0}
    catch_error M3.default
    catch_error M4.default

    catch_error M1.min_size
    catch_error M1.max_size
    assert      M2.min_size == 1
    catch_error M2.max_size
    catch_error M3.min_size
    assert      M3.max_size == 2
    assert      M4.min_size == 1
    assert      M4.max_size == 2
  end

  defmodule T0 do
    use Croma.SubtypeOfTuple, elem_modules: [], default: {}
  end
  defmodule T1 do
    use Croma.SubtypeOfTuple, elem_modules: [I1]
  end
  defmodule T3 do
    use Croma.SubtypeOfTuple, elem_modules: [I1, S1, L1]
  end

  test "Croma.SubtypeOfTuple: validate/1" do
    assert T0.validate(nil) == {:error, {:invalid_value, [T0]}}
    assert T0.validate({} ) == {:ok, {}}

    assert T1.validate({} ) == {:error, {:invalid_value, [T1]}}
    assert T1.validate({0}) == {:error, {:invalid_value, [T1, I1]}}
    assert T1.validate({1}) == {:ok, {1}}

    assert T3.validate({}            ) == {:error, {:invalid_value, [T3]}}
    assert T3.validate({1, ""   , []}) == {:error, {:invalid_value, [T3, S1]}}
    assert T3.validate({1, "foo", []}) == {:ok, {1, "foo", []}}
  end

  test "Croma.SubtypeOfTuple: default/0" do
    assert      T0.default == {}
    catch_error T1.default
    catch_error T3.default
  end
end
