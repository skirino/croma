defmodule Croma.New1ExistenceTest do
  use Croma.TestCase

  defmodule WithNew1 do
    def new(_), do: :ok
  end

  defmodule WithoutNew1 do
  end

  describe "Without AssumedModuleStore, has_new1?/1" do
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
      For these cases, try :croma compiler instead of :elixir compiler.\
      """, fn ->
        New1Existence.has_new1?(NonExisting)
      end
    end
  end

  describe "With AssumedModuleStore, has_new1?/1" do
    setup do
      New1Existence.prepare()
      # `New1Existence.cleanup/0` is not required
      # because `AssumedModuleStore` will be stopped along with the test process.
      :ok
    end

    test "should return true when the given module exports new/1" do
      assert New1Existence.has_new1?(WithNew1)
    end

    test "should return false when the given module doesn't export new/1" do
      refute New1Existence.has_new1?(WithoutNew1)
    end

    test "should store the given module and return true when it doesn't exist" do
      assert New1Existence.has_new1?(NonExisting)
      assert New1Existence.get_modules_need_confirmation() == [NonExisting]
    end
  end
end
