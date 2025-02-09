defmodule Croma.New1Existence do
  @moduledoc false

  defmodule AssumedModulesStore do
    @moduledoc false

    @spec put(module) :: :ok
    def put(mod) do
      ensure_started()
      Agent.update(__MODULE__, &MapSet.put(&1, mod))
    end

    defp ensure_started() do
      unless exists?() do
        case Agent.start(fn -> MapSet.new() end, [name: __MODULE__]) do
          {:ok, _pid}                        -> nil
          {:error, {:already_started, _pid}} -> nil
        end
      end
    end

    defp exists?() do
      Process.whereis(__MODULE__) != nil
    end

    @spec get() :: [module]
    def get() do
      if exists?() do
        Agent.get(__MODULE__, &MapSet.to_list/1)
      else
        []
      end
    end

    @spec stop() :: :ok
    def stop() do
      if exists?() do
        Agent.stop(__MODULE__)
      else
        :ok
      end
    end
  end

  def cleanup() do
    :ok = AssumedModulesStore.stop()
  end

  # The second argument `compilers` is for testing purpose only.
  @doc """
  Returns true if `mod` exports `new/1`, otherwise false.

  Note that `mod` is compiled and loaded if needed.

  When the `:croma` compiler runs after `:elixir` compiler, this function assumes that
  `mod` has `new/1` even if `mod` is currently unable to be loaded as following cases:

  - `mod` has not been defined yet because `mod` is open or defined later in the same file.
  - `mod` is involved in cyclic dependency causing compiler deadlock.
  """
  @spec has_new1?(module, list(atom)) :: boolean
  def has_new1?(mod, compilers \\ Mix.Task.Compiler.compilers()) do
    cond do
      ensure_compiled_and_loaded?(mod) ->
        function_exported?(mod, :new, 1)
      uses_custom_compiler_after_elixir_compiler?(compilers) ->
        :ok = AssumedModulesStore.put(mod)
        # Assume that `mod` has `new/1`; by this assumption, modules whose
        # existence of `new/1` depends on existence of `mod.new/1` (e.g.,
        # modules `use`ing `Croma.SubtypeOfList`) will also have `new/1`.
        # This is convenient when `mod` and those modules refer to each other.
        true
      true ->
        mod_str = inspect(mod)
        raise """
        Cannot determine whether #{mod_str} has new/1 or not. \
        This might be because #{mod_str} is mutually referred from another module \
        or #{mod_str} is referred from its child module. \
        For these cases, try using :croma compiler (you need to put it after :elixir compiler).\
        """
    end
  end

  defp ensure_compiled_and_loaded?(mod) do
    case Code.ensure_compiled(mod) do
      {:module, ^mod} ->
        # Although `Code.ensure_compiled/1` didn't return an error,
        # `Code.ensure_loaded?/1` can still return false when `mod` is open.
        Code.ensure_loaded?(mod)
      {:error, reason} when reason in [:nofile, :unavailable] ->
        # We expect that `mod` will be compiled in the future, and thus don't raise.
        # `:nofile` indicates that `mod` is defined later in the same file, and
        # `:unavailable` indicates that `mod` is involved in cyclic dependency.
        false
      {:error, reason} ->
        raise "Cannot load module #{inspect(mod)} due to reason #{inspect(reason)}"
    end
  end

  defp uses_custom_compiler_after_elixir_compiler?(compilers) do
    with [:elixir | compilers_after_elixir] <- Enum.drop_while(compilers, &(&1 != :elixir)) do
      :croma in compilers_after_elixir
    else
      # Elixir source files might be compiled by custom compilers other than `:elixir` compiler.
      # To allow such cases, we check only whether the `:croma` compiler is used.
      _ -> :croma in compilers
    end
  end

  @doc """
  Returns modules which are assumed to have `new/1` in `has_new1?/1`.
  """
  @spec modules_to_confirm() :: [module]
  def modules_to_confirm() do
    AssumedModulesStore.get()
  end
end
