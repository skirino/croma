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
    assert I3.default == -5
    assert I4.default ==  0
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
    assert F2.default == 1.0
    assert F3.default == 0.5
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
    assert A1.validate(:a4 ) == {:error, "validation error for #{A1}: :a4"}
    assert A1.validate("a4") == {:error, "validation error for #{A1}: \"a4\""}
    assert A1.validate(nil ) == {:error, "validation error for #{A1}: nil"}
    assert A1.validate([]  ) == {:error, "validation error for #{A1}: []"}
  end

  test "Croma.SubtypeOfAtom: default/0" do
    assert A1.default == :a1
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
    assert L1.validate([0]) == {:error, {:invalid_value, [I1]}}

    assert L2.validate([]          ) == {:ok   , []}
    assert L2.validate([1, 2, 3]   ) == {:ok   , [1, 2, 3]}
    assert L2.validate([1, 2, 11]  ) == {:error, {:invalid_value, [I2]}}
    assert L2.validate([1, 2, 3, 4]) == {:error, "validation error for #{L2}: [1, 2, 3, 4]"}

    assert L3.validate([ 1]    ) == {:error, {:invalid_value, [I3]}}
    assert L3.validate([-1]    ) == {:error, "validation error for #{L3}: [-1]"}
    assert L3.validate([-1, -2]) == {:ok   , [-1, -2]}

    assert L4.validate([]          ) == {:error, "validation error for #{L4}: []"}
    assert L4.validate([-5]        ) == {:ok   , [-5]}
    assert L4.validate([-5, 0, 5]  ) == {:ok   , [-5, 0, 5]}
    assert L4.validate([-5, 10]    ) == {:error, {:invalid_value, [I4]}}
    assert L4.validate([0, 0, 0, 0]) == {:error, "validation error for #{L4}: [0, 0, 0, 0]"}
  end

  test "Croma.SubtypeOfList: default/0" do
    assert L1.default == []
    assert L2.default == [0, 0, 0]
    catch_error L3.default
    catch_error L4.default
  end
end
