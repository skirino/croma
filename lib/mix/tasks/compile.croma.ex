defmodule Mix.Tasks.Compile.Croma do
  @moduledoc """
  Compiles Elixir source files and checks if Croma consistently defines functions.

  Must be used instead of `:elixir` compiler
  (do not use `:elixir` and `:croma` compilers at the same time).
  """

  use Mix.Task.Compiler
  alias Croma.New1Existence

  @impl Mix.Task.Compiler
  def run(args) do
    New1Existence.prepare()
    result =
      with {:ok, _} = result <- compile_elixir(args) do
        confirm_assumed_new1_existence()
        result
      end
    New1Existence.cleanup()
    result
  end

  defp compile_elixir(args) do
    Mix.Task.Compiler.normalize(Mix.Task.run("compile.elixir", args), :elixir)
  end

  defp confirm_assumed_new1_existence() do
    inconsistent_mods =
      Enum.reject(New1Existence.get_modules_need_confirmation(), fn m ->
        Code.ensure_loaded?(m) and function_exported?(m, :new, 1)
      end)
    if inconsistent_mods != [] do
      Mix.raise("""
      Croma couldn't consistently define new/1 functions.
      There is missing new/1 in the following modules (or missing module itself):

      #{Enum.map_join(inconsistent_mods, "\n", &("* " <> inspect(&1)))}

      Consider defining new/1 just wrapping a valid value as follows:

          def new(v), do: Croma.Result.wrap_if_valid(v, __MODULE__)
      """)
    end
  end
end
