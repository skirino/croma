defmodule Croma.TypeUtilTest do
  use Croma.TestCase

  test "resolve_primitive/2" do
    env = __ENV__
    assert TypeUtil.resolve_primitive(String , :t        , env) == {:ok, :binary}
    assert TypeUtil.resolve_primitive(:erlang, :timestamp, env) == {:ok, :tuple}

    assert TypeUtil.resolve_primitive(NonexistingModule, :foo        , env) == :error
    assert TypeUtil.resolve_primitive(String           , :nonexisting, env) == :error

    [
      {:b1, {:ok, :binary}},
      {:b2, {:ok, :binary}},
      {:b3, {:ok, :binary}},

      {:l1, {:ok, :list}},
      {:l2, {:ok, :list}},
      {:l3, {:ok, :list}},
      {:l4, {:ok, :list}},

      {:t0, {:ok, :tuple}},
      {:t1, {:ok, :tuple}},
      {:t2, {:ok, :tuple}},
      {:t3, {:ok, :tuple}},
      {:t4, {:ok, :tuple}},

      {:m1, {:ok, :map}},
      {:m2, {:ok, :map}},
      {:m3, {:ok, :map}},
      {:m4, {:ok, :map}},

      {:f1, {:ok, :fun}},
      {:f2, {:ok, :fun}},

      {:u, :error},
    ] |> Enum.each(fn {t, r} ->
      # module attribute based
      assert apply(Croma.Testonly, t, []) == r

      # beam file based
      assert TypeUtil.resolve_primitive(Croma.Testonly, t, env) == r
    end)
  end
end
