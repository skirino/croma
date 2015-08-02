defmodule Croma.SubtypeTest do
  use ExUnit.Case

  defmodule I1 do
    use Croma.SubtypeOfInt, [min: 1]
  end
  defmodule I2 do
    use Croma.SubtypeOfInt, [min: 0, max: 10]
  end
  defmodule I3 do
    use Croma.SubtypeOfInt, [max: -1]
  end
  defmodule I4 do
    use Croma.SubtypeOfInt, [min: -5, max: 5]
  end

  test "Croma.SubtypeOfInt: validate/1" do
    assert I1.validate(0) == {:error, "validation error for #{I1}: 0"}
    assert I1.validate(1) == {:ok   , 1}

    assert I2.validate(-1) == {:error, "validation error for #{I2}: -1"}
    assert I2.validate( 0) == {:ok   ,  0}
    assert I2.validate(10) == {:ok   , 10}
    assert I2.validate(11) == {:error, "validation error for #{I2}: 11"}

    assert I3.validate(-1) == {:ok   , -1}
    assert I3.validate( 0) == {:error, "validation error for #{I3}: 0"}

    assert I4.validate(-6) == {:error, "validation error for #{I4}: -6"}
    assert I4.validate(-5) == {:ok   , -5}
    assert I4.validate( 5) == {:ok   ,  5}
    assert I4.validate( 6) == {:error, "validation error for #{I4}: 6"}

    assert I1.validate(nil) == {:error, "validation error for #{I1}: nil"}
    assert I1.validate([] ) == {:error, "validation error for #{I1}: []"}
  end
end
