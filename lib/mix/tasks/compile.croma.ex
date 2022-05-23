defmodule Mix.Tasks.Compile.Croma do
  @moduledoc """
  Compiles Elixir source files and recompiles some of them
  to correct inconsistency between function dependency defined by Croma if any.

  Must be used instead of `:elixir` compiler
  (do not use `:elixir` and `:croma` compiler at the same time).
  """

  use Mix.Task.Compiler
  alias Croma.New1Existence

  @impl Mix.Task.Compiler
  def run(args) do
    New1Existence.prepare()
    result =
      with {:ok, diagnostics} <- compile_elixir(args) do
        case recompile_if_needed(args) do
          {status, new_diagnostics} when status in [:ok, :noop] ->
            {:ok, diagnostics ++ new_diagnostics}
          {:error, new_diagnostics} ->
            {:error, diagnostics ++ new_diagnostics}
        end
      end
    New1Existence.cleanup()
    result
  end

  defp recompile_if_needed(args) do
    case New1Existence.determine_and_get_modules_to_recompile() do
      []                -> {:noop, []}
      mods_to_recompile -> touch_and_recompile(mods_to_recompile, args)
    end
  end

  defp touch_and_recompile(mods_to_recompile, args) do
    sources = Enum.map(mods_to_recompile, &(&1.module_info(:compile)[:source]))
    touch_sources(sources)
    beam_paths =
      Mix.Project.compile_path()
      |> Path.join("*.beam")
      |> Path.wildcard()
    unlock_module_creation_by_type_gen(beam_paths)
    delete_beams(sources, beam_paths)
    recompile_elixir(args)
  end

  if Mix.env() == :test do
    @future_time {{3000, 1, 1}, {0, 0, 0}}
    defp touch_sources(sources) do
      Enum.each(sources, &File.touch!(&1, @future_time))
    end
  else
    defp touch_sources(sources) do
      # Wait 1 second before touching files so that elixir compiler recognizes them as stale.
      Process.sleep(1000)
      Enum.each(sources, &File.touch!/1)
    end
  end

  defp unlock_module_creation_by_type_gen(beam_paths) do
    beam_paths
    |> Enum.map(&Path.basename(&1, ".beam"))
    |> Enum.filter(&String.starts_with?(&1, "Elixir.Croma.TypeGen."))
    |> Enum.map(&String.to_existing_atom/1)
    |> Enum.each(&Croma.TypeGen.ensure_unlock_module_creation/1)
  end

  if Version.match?(System.version(), ">= 1.13.0") do
    # In Elixir v1.13+, recompilation won't be triggered if some .beam files exist.
    defp delete_beams(sources, beam_paths) do
      # When multiple .beam files are built from the same source file,
      # which one should be removed to trigger recompilation depends on elixir's manifest file.
      # So we remove all .beam files built from the same source file.
      beams_form_same_sources =
        beam_paths
        |> Enum.map(&String.to_charlist/1)
        |> Enum.filter(fn beam ->
          {:ok, {_mod, info}} = :beam_lib.chunks(beam, [:compile_info])
          info[:compile_info][:source] in sources
        end)
      Enum.each(beams_form_same_sources, &File.rm/1)
    end
  else
    defp delete_beams(_, _), do: :ok
  end

  defp compile_elixir(args) do
    Mix.Task.Compiler.normalize(Mix.Task.run("compile.elixir", args), :elixir)
  end

  defp recompile_elixir(args) do
    Mix.Task.Compiler.normalize(Mix.Task.rerun("compile.elixir", args), :elixir)
  end
end
