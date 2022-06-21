defmodule Croma.New1Existence do
  @moduledoc false

  defmodule AssumedModuleStore do
    @moduledoc false

    @spec start() :: :ok
    def start() do
      {:ok, _pid} = Agent.start_link(fn -> [] end, [name: __MODULE__])
      :ok
    end

    @spec stop() :: :ok
    def stop() do
      Agent.stop(__MODULE__)
    end

    @spec available?() :: boolean
    def available?() do
      Process.whereis(__MODULE__) != nil
    end

    @spec inserted_new(module) :: :ok
    def inserted_new(mod) do
      Agent.update(__MODULE__, fn current ->
        if mod in current, do: current, else: [mod | current]
      end)
    end

    @spec get() :: [module]
    def get() do
      Agent.get(__MODULE__, &(&1))
    end
  end

  def prepare() do
    :ok = AssumedModuleStore.start()
  end

  def cleanup() do
    :ok = AssumedModuleStore.stop()
  end

  @doc """
  Returns true if `mod` exports `new/1`, otherwise false.

  Note that `mod` is compiled and loaded if needed.

  When `prepare/0` has been called, this function assumes that `mod` has `new/1`
  even if `mod` is currently unable to be loaded (`mod` is defined later in the same file,
  or `mod` is involved in cyclic dependency).
  """
  @spec has_new1?(module) :: boolean
  def has_new1?(mod) do
    cond do
      ensure_compiled_and_loaded?(mod) ->
        function_exported?(mod, :new, 1)
      AssumedModuleStore.available?() ->
        :ok = AssumedModuleStore.inserted_new(mod)
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
        For these cases, try :croma compiler instead of :elixir compiler.\
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

  @doc """
  Returns modules which are assumed to have `new/1` in `has_new1?/1`.

  Note that `prepare/0` must be called beforehand.
  """
  @spec get_modules_need_confirmation() :: [module]
  def get_modules_need_confirmation() do
    true = AssumedModuleStore.available?()
    AssumedModuleStore.get()
  end
end
