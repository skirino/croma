defmodule Croma.New1ExistenceTest do
  use Croma.TestCase

  @compilers_with_croma Mix.compilers() ++ [:croma]
  @custom_compilers_with_croma [:custom_elixir, :croma]

  defmodule WithNew1 do
    def new(_), do: :ok
  end

  defmodule WithoutNew1 do
  end

  setup do
    on_exit(fn ->
      New1Existence.cleanup()
    end)
  end

  describe "has_new1?/1 without :croma compiler" do
    test "should return true when the given module exports new/1" do
      assert New1Existence.has_new1?(WithNew1)
    end

    test "should return false when the given module doesn't export new/1" do
      refute New1Existence.has_new1?(WithoutNew1)
    end

    test "should raise when the given module doesn't exist" do
      assert_raise RuntimeError, """
      Cannot determine whether NonExisting has new/1 or not. \
      This might be because NonExisting is mutually referred from another module \
      or NonExisting is referred from its child module. \
      For these cases, try using :croma compiler (you need to put it after :elixir compiler).\
      """, fn ->
        New1Existence.has_new1?(NonExisting)
      end
      assert New1Existence.modules_to_confirm() == []
    end
  end

  describe "has_new2?/1 with :croma compiler" do
    test "should return true when the given module exports new/1" do
      assert New1Existence.has_new1?(WithNew1, @compilers_with_croma)
    end

    test "should return false when the given module doesn't export new/1" do
      refute New1Existence.has_new1?(WithoutNew1, @compilers_with_croma)
    end

    test "should store the given module and return true when it doesn't exist" do
      assert New1Existence.has_new1?(NonExisting, @compilers_with_croma)
      assert New1Existence.has_new1?(NonExisting2, @compilers_with_croma)
      stored_mods = New1Existence.modules_to_confirm()
      assert Enum.sort(stored_mods) == [NonExisting, NonExisting2]
    end
  end

  describe "has_new2?/1 with :croma and without :elixir compiler" do
    test "should return true when the given module exports new/1" do
      assert New1Existence.has_new1?(WithNew1, @custom_compilers_with_croma)
    end

    test "should return false when the given module doesn't export new/1" do
      refute New1Existence.has_new1?(WithoutNew1, @custom_compilers_with_croma)
    end

    test "should store the given module and return true when it doesn't exist" do
      assert New1Existence.has_new1?(NonExisting, @custom_compilers_with_croma)
      assert New1Existence.has_new1?(NonExisting2, @custom_compilers_with_croma)
      stored_mods = New1Existence.modules_to_confirm()
      assert Enum.sort(stored_mods) == [NonExisting, NonExisting2]
    end
  end
end
