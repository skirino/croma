defmodule Mix.Tasks.Compile.CromaTest do
  use ExUnit.Case
  alias Croma.TypeGen.{Nilable, ListOf, Union}

  @tmpdir_root Path.expand("../../../tmp/#{__MODULE__}", __DIR__)

  if Version.match?(System.version(), ">= 1.10.0") do
    # Elixir 1.10+ warns about functions which are undefined at compile time.
    @compile {:no_warn_undefined, {L, :new, 1}}
    @compile {:no_warn_undefined, {M, :new, 1}}
    @compile {:no_warn_undefined, {S, :new, 1}}
    @compile {:no_warn_undefined, {A.T, :new, 1}}
  end

  defmacrop in_project(callback) do
    quote bind_quoted: [lineno: Integer.to_string(__CALLER__.line), callback: callback] do
      in_project_impl(lineno, callback)
    end
  end

  defp in_project_impl(lineno, callback) do
    tmpdir = Path.join(@tmpdir_root, lineno)
    lib_path = Path.join(tmpdir, "lib")
    mix_path = Path.join(tmpdir, "mix.exs")
    str_name = "croma_test_" <> lineno
    app_name = String.to_atom(str_name)
    File.mkdir_p!(lib_path)
    File.write!(mix_path, """
    defmodule #{Macro.camelize(str_name)}.MixProject do
      use Mix.Project
      def project, do: [
        app: #{inspect(app_name)},
        version: "0.1.0",
        compilers: [:elixir, :croma]
      ]
      def application, do: [extra_applications: [:croma]]
    end
    """)
    Mix.Project.in_project(app_name, tmpdir, fn _ -> callback.() end)
  end

  defp configure_mix_shell(_context) do
    mix_shell = Mix.shell()
    Mix.shell(Mix.Shell.Process)
    on_exit(fn ->
      Mix.shell(mix_shell)
    end)
  end

  defp setup_module_cleaner(_context) do
    code_path = :code.get_path()
    loaded_mods = :code.all_loaded()
    on_exit(fn ->
      :code.set_path(code_path)
      Enum.each(:code.all_loaded() -- loaded_mods, fn {mod, file} ->
        if file_for_temporary_module?(file) do
          :code.purge(mod)
          :code.delete(mod)
        end
      end)
    end)
  end

  defp file_for_temporary_module?([]), do: true
  defp file_for_temporary_module?(file) do
    is_list(file) and file |> List.to_string() |> String.starts_with?(@tmpdir_root)
  end

  setup_all do
    File.rm_rf!(@tmpdir_root)
    File.mkdir_p!(@tmpdir_root)
  end

  setup [:configure_mix_shell, :setup_module_cleaner]

  test "should compile self-referenced SubtypeOfList" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule L do
        use Croma.SubtypeOfList, elem_module: __MODULE__
      end
      """)

      assert Mix.Tasks.Compile.run([]) == {:ok, []}

      assert_received {:mix_shell, :info, ["Compiling 1 file (.ex)"]}

      assert L.new([])             == {:ok, []}
      assert L.new([[]])           == {:ok, [[]]}
      assert L.new([[[]]])         == {:ok, [[[]]]}
      assert L.new(["not_list"])   == {:error, {:invalid_value, [L, L]}}
      assert L.new([["not_list"]]) == {:error, {:invalid_value, [L, L, L]}}
    end)
  end

  test "should compile self-referenced SubtypeOfMap" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule M do
        use Croma.SubtypeOfMap, key_module: Croma.Atom, value_module: __MODULE__
      end
      """)

      assert Mix.Tasks.Compile.run([]) == {:ok, []}

      assert_received {:mix_shell, :info, ["Compiling 1 file (.ex)"]}

      assert M.new(%{})                   == {:ok, %{}}
      assert M.new(%{a: %{}})             == {:ok, %{a: %{}}}
      assert M.new(%{a: %{a: %{}}})       == {:ok, %{a: %{a: %{}}}}
      assert M.new(%{a: "not_map"})       == {:error, {:invalid_value, [M, M]}}
      assert M.new(%{a: %{a: "not_map"}}) == {:error, {:invalid_value, [M, M, M]}}
    end)
  end

  test "should compile Struct self-referencing via TypeGen.nilable/1" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule S do
        import Croma.TypeGen
        use Croma.Struct, fields: [f: nilable(__MODULE__)]
      end
      """)

      assert Mix.Tasks.Compile.run([]) == {:ok, []}

      assert_received {:mix_shell, :info, ["Compiling 1 file (.ex)"]}

      assert S.new(%{})                   == {:ok, struct(S, f: nil)}
      assert S.new(%{f: %{}})             == {:ok, struct(S, f: struct(S, f: nil))}
      assert S.new(%{f: %{f: %{}}})       == {:ok, struct(S, f: struct(S, f: struct(S, f: nil)))}
      assert S.new(%{f: "not_map"})       == {:error, {:invalid_value, [S, {Nilable.S, :f}, S]}}
      assert S.new(%{f: %{f: "not_map"}}) == {:error, {:invalid_value, [S, {Nilable.S, :f}, S, {Nilable.S, :f}, S]}}
    end)
  end

  test "should compile Struct self-referencing via TypeGen.list_of/1" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule S do
        import Croma.TypeGen
        use Croma.Struct, fields: [f: list_of(__MODULE__)]
      end
      """)

      assert Mix.Tasks.Compile.run([]) == {:ok, []}

      assert_received {:mix_shell, :info, ["Compiling 1 file (.ex)"]}

      assert S.new(%{})                       == {:ok, struct(S, f: [])}
      assert S.new(%{f: [%{}]})               == {:ok, struct(S, f: [struct(S, f: [])])}
      assert S.new(%{f: [%{f: [%{}]}]})       == {:ok, struct(S, f: [struct(S, f: [struct(S, f: [])])])}
      assert S.new(%{f: "not_list"})          == {:error, {:invalid_value, [S, {ListOf.S, :f}]}}
      assert S.new(%{f: ["not_map"]})         == {:error, {:invalid_value, [S, S]}}
      assert S.new(%{f: [%{f: "not_list"}]})  == {:error, {:invalid_value, [S, S, {ListOf.S, :f}]}}
      assert S.new(%{f: [%{f: ["not_map"]}]}) == {:error, {:invalid_value, [S, S, S]}}
    end)
  end

  test "should compile Struct self-referencing via TypeGen.union/1" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule S do
        import Croma.TypeGen
        use Croma.Struct, fields: [f: union([Croma.Atom, __MODULE__])]
      end
      """)

      assert Mix.Tasks.Compile.run([]) == {:ok, []}

      assert_received {:mix_shell, :info, ["Compiling 1 file (.ex)"]}

      union_mod = Union.E85E4B71A2CDA1BDD2AE026F83418B53
      assert S.new(%{})                    == {:error, {:value_missing, [S, {union_mod, :f}]}}
      assert S.new(%{f: :a})               == {:ok, struct(S, f: :a)}
      assert S.new(%{f: %{f: :a}})         == {:ok, struct(S, f: struct(S, f: :a))}
      assert S.new(%{f: "not_atom"})       == {:error, {:invalid_value, [S, {union_mod, :f}]}}
      assert S.new(%{f: %{f: "not_atom"}}) == {:error, {:invalid_value, [S, {union_mod, :f}]}}
    end)
  end

  test "should compile SubtypeOfTuple defined inside a parent module with new/1" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule A do
        defmodule T do
          use Croma.SubtypeOfTuple, elem_modules: [A, A]
        end
        use Croma.SubtypeOfAtom, values: [:a]
      end
      """)

      assert Mix.Tasks.Compile.run([]) == {:ok, []}

      assert_received {:mix_shell, :info, ["Compiling 1 file (.ex)"]}

      assert A.T.new({:a, :a})   == {:ok, {:a, :a}}
      assert A.T.new({"a", "a"}) == {:ok, {:a, :a}}
      assert A.T.new({:a, :b})   == {:error, {:invalid_value, [A.T, A]}}
      assert A.T.new({"a", "b"}) == {:error, {:invalid_value, [A.T, A]}}
    end)
  end

  test "should compile mutually referencing Struct and SubtypeOfList" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule S do
        use Croma.Struct, fields: [f: L]
      end

      defmodule L do
        use Croma.SubtypeOfList, elem_module: S
      end
      """)

      assert Mix.Tasks.Compile.run([]) == {:ok, []}

      assert_received {:mix_shell, :info, ["Compiling 1 file (.ex)"]}

      assert S.new(%{})                      == {:error, {:value_missing, [S, {L, :f}]}}
      assert S.new(%{f: []})                 == {:ok, struct(S, f: [])}
      assert S.new(%{f: [%{}]})              == {:error, {:value_missing, [S, {L, :f}, S, {L, :f}]}}
      assert S.new(%{f: [%{f: []}]})         == {:ok, struct(S, f: [struct(S, f: [])])}
      assert S.new(%{f: "not_list"})         == {:error, {:invalid_value, [S, {L, :f}]}}
      assert S.new(%{f: ["not_map"]})        == {:error, {:invalid_value, [S, {L, :f}, S]}}
      assert S.new(%{f: [%{f: "not_list"}]}) == {:error, {:invalid_value, [S, {L, :f}, S, {L, :f}]}}

      assert L.new([])                 == {:ok, []}
      assert L.new([%{}])              == {:error, {:value_missing, [L, S, {L, :f}]}}
      assert L.new([%{f: []}])         == {:ok, [struct(S, f: [])]}
      assert L.new(["not_map"])        == {:error, {:invalid_value, [L, S]}}
      assert L.new([%{f: "not_list"}]) == {:error, {:invalid_value, [L, S, {L, :f}]}}
    end)
  end

  test "should compile mutually referencing Struct and SubtypeOfMap defined in different files" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule S do
        use Croma.Struct, fields: [f: M]
      end
      """)

      File.write!("lib/b.ex", """
      defmodule M do
        use Croma.SubtypeOfMap, key_module: Croma.Atom, value_module: S
      end
      """)

      assert Mix.Tasks.Compile.run([]) == {:ok, []}

      assert_received {:mix_shell, :info, ["Compiling 2 files (.ex)"]}

      assert S.new(%{})                         == {:error, {:value_missing, [S, {M, :f}]}}
      assert S.new(%{f: %{}})                   == {:ok, struct(S, f: %{})}
      assert S.new(%{f: %{a: %{}}})             == {:error, {:value_missing, [S, {M, :f}, S, {M, :f}]}}
      assert S.new(%{f: %{a: %{f: %{}}}})       == {:ok, struct(S, f: %{a: struct(S, f: %{})})}
      assert S.new(%{f: "not_map"})             == {:error, {:invalid_value, [S, {M, :f}]}}
      assert S.new(%{f: %{a: "not_map"}})       == {:error, {:invalid_value, [S, {M, :f}, S]}}
      assert S.new(%{f: %{a: %{f: "not_map"}}}) == {:error, {:invalid_value, [S, {M, :f}, S, {M, :f}]}}

      assert M.new(%{})                   == {:ok, %{}}
      assert M.new(%{a: %{}})             == {:error, {:value_missing, [M, S, {M, :f}]}}
      assert M.new(%{a: %{f: %{}}})       == {:ok, %{a: struct(S, f: %{})}}
      assert M.new(%{a: "not_map"})       == {:error, {:invalid_value, [M, S]}}
      assert M.new(%{a: %{f: "not_map"}}) == {:error, {:invalid_value, [M, S, {M, :f}]}}
    end)
  end

  test "should raise when referring to a parent module without new/1" do
    in_project(fn ->
      File.write!("lib/a.ex", """
      defmodule I do
        defmodule T do
          use Croma.SubtypeOfTuple, elem_modules: [I, I]
        end
        use Croma.SubtypeOfInt, min: 0
      end
      """)

      assert_raise Mix.Error, """
      Croma couldn't consistently define new/1 functions.
      There is missing new/1 in the following modules (or missing module itself):

      * I

      Consider defining new/1 just wrapping a valid value as follows:

          def new(v), do: Croma.Result.wrap_if_valid(v, __MODULE__)
      """, fn ->
        assert Mix.Tasks.Compile.run([])
      end
    end)
  end
end
