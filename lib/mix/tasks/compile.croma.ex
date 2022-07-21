defmodule Mix.Tasks.Compile.Croma do
  @moduledoc """
  Custom compiler that checks if Croma consistently defines `new/1` functions.

  You need to put `:croma` compiler after `:elixir` compiler.
  """

  use Mix.Task.Compiler
  alias Croma.New1Existence

  @impl Mix.Task.Compiler
  def run(_args) do
    mods = New1Existence.modules_to_confirm()
    New1Existence.cleanup()
    case Enum.reject(mods, &has_new1?/1) do
      [] ->
        {:ok, []}
      inconsistent_mods ->
        Mix.raise("""
        Croma couldn't consistently define new/1 functions.
        There is missing new/1 in the following modules (or missing module itself):

        #{Enum.map_join(inconsistent_mods, "\n", &("* " <> inspect(&1)))}

        Consider defining new/1 just wrapping a valid value as follows:

            def new(v), do: Croma.Result.wrap_if_valid(v, __MODULE__)
        """)
    end
  end

  defp has_new1?(mod) do
    Code.ensure_loaded?(mod) and function_exported?(mod, :new, 1)
  end
end
