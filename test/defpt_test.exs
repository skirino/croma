defmodule Croma.DefptTest do
  use ExUnit.Case

  defmodule M do
    use Croma

    defpt f() do
      1
    end
  end

  test "should define accessible function in test environment" do
    assert M.f() == 1
  end
end
