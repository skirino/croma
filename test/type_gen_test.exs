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

  defmodule S do
    use Croma.Struct, i: nilable(I)
  end

  test "struct definition with Croma.TypeGen.nilable" do
    s = S.new([i: 0])
    assert s == %S{i: 0}
    catch_error S.new(%{"i" => -1})

    assert S.validate(%{i: 10})     == S.update(s, [i: 10])
    assert S.validate(%{"i" => -1}) == {:error, "validation error for #{I}: -1"}
    assert S.update(s, %{i: -1})    == {:error, "validation error for #{I}: -1"}
  end
end
