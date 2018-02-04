defmodule Croma.DebugAssertTest do
  use ExUnit.Case

  defmodule Enabled do
    import Croma.DebugAssert
    def f(i, j) do
      debug_assert(i < j)
      i + j
    end
  end

  Application.put_env(:croma, :debug_assert, false)

  defmodule Disabled do
    import Croma.DebugAssert
    def f(i, j) do
      debug_assert(i < j)
      i + j
    end
  end

  Application.put_env(:croma, :debug_assert, true)

  test "debug_assert/2" do
    assert      Disabled.f(0, 1) == 1
    assert      Disabled.f(2, 1) == 3
    assert      Enabled .f(0, 1) == 1
    catch_error Enabled .f(2, 1)
  end
end
