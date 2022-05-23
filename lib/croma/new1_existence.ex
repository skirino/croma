defmodule Croma.New1Existence do
  @moduledoc false

  defmodule StatusTable do
    @moduledoc false
    # Stores `{module, :assumed | {:determined, boolean}}`,
    # which represents status of `new/1` existence in the module.

    def create() do
      :ets.new(__MODULE__, [:set, :public, :named_table])
    end

    def delete() do
      :ets.delete(__MODULE__)
    end

    def available?() do
      :ets.info(__MODULE__, :name) == __MODULE__
    end

    @spec insert_assumed(module) :: true
    def insert_assumed(mod) do
      :ets.insert(__MODULE__, {mod, :assumed})
    end

    @spec insert_determined(module, boolean) :: true
    def insert_determined(mod, has_new1?) do
      :ets.insert(__MODULE__, {mod, {:determined, has_new1?}})
    end

    @spec get_determined_value(module) :: boolean | nil
    def get_determined_value(mod) do
      case :ets.lookup(__MODULE__, mod) do
        [{^mod, {:determined, has_new1?}}] -> has_new1?
        _                                  -> nil
      end
    end

    @spec any_determined?() :: boolean
    def any_determined?() do
      :ets.match(__MODULE__, {:_, {:determined, :_}}) != []
    end

    @spec list_assumed_modules() :: [module]
    def list_assumed_modules() do
      __MODULE__
      |> :ets.match({:"$1", :assumed})
      |> List.flatten()
    end
  end

  defmodule EvaluatorTable do
    @moduledoc false
    # Stores `{module, mod_fun_args}`.

    @typedoc "Module, function name, and arguments to evaluate `new/1` existence."
    @type mod_fun_args :: {module, atom, list}

    def create() do
      :ets.new(__MODULE__, [:set, :public, :named_table])
    end

    def delete() do
      :ets.delete(__MODULE__)
    end

    def available?() do
      :ets.info(__MODULE__, :name) == __MODULE__
    end

    @spec insert_mod_fun_args(module, mod_fun_args) :: true
    def insert_mod_fun_args(mod, mod_fun_args) do
      :ets.insert(__MODULE__, {mod, mod_fun_args})
    end

    @spec evaluate_if_possible(module) :: boolean | nil
    def evaluate_if_possible(mod) do
      case :ets.lookup(__MODULE__, mod) do
        [{^mod, {m, f, args}}] -> apply(m, f, args)
        []                     -> nil
      end
    end
  end

  def prepare() do
    StatusTable.create()
    EvaluatorTable.create()
  end

  def cleanup() do
    StatusTable.delete()
    EvaluatorTable.delete()
  end

  @doc """
  """
  @spec has_new1?(module, module | nil) :: boolean
  def has_new1?(mod, mod_being_compiled \\ nil) do
    if StatusTable.available?() do
      has_new1_with_table?(mod, mod_being_compiled)
    else
      has_new1_without_table?(mod, mod_being_compiled)
    end
  end

  @doc """
  """
  @spec store_mod_fun_args_to_evaluate(module, EvaluatorTable.mod_fun_args) :: :ok
  def store_mod_fun_args_to_evaluate(mod, mod_fun_args) do
    if EvaluatorTable.available?() do
      EvaluatorTable.insert_mod_fun_args(mod, mod_fun_args)
    end
    :ok
  end

  @doc """
  """
  @spec determine_and_get_modules_to_recompile() :: [module]
  def determine_and_get_modules_to_recompile() do
    true = StatusTable.available?()
    true = EvaluatorTable.available?()
    determine_and_get_modules_to_recompile_recursively()
  end

  defp has_new1_with_table?(mod, mod_being_compiled) do
    with nil <- StatusTable.get_determined_value(mod) do
      if ensure_compiled_and_loaded?(mod) do
        function_exported?(mod, :new, 1)
      else
        if StatusTable.any_determined?() or mod_being_compiled == nil do
          raise "Cannot assume #{inspect(mod)}.new/1 after the first compilation"
        end
        # Assume that `new/1` exists to define `new/1` in circularly referenced modules.
        # In addition, we suppress warning emitted when this assumption is wrong (Elixir 1.10+).
        StatusTable.insert_assumed(mod)
        suppress_warning_for_undefined_new1(mod_being_compiled, mod)
        true
      end
    end
  end

  defp ensure_compiled_and_loaded?(mod) do
    case Code.ensure_compiled(mod) do
      {:module, ^mod} ->
        # Although `Code.ensure_compiled/1` didn't return an error,
        # `Code.ensure_loaded?/1` can still return false when `mod` is open.
        Code.ensure_loaded?(mod)
      {:error, reason} when reason in [:nofile, :unavailable] ->
        # We can expect that `mod` will be compiled in the future.
        # `:nofile` indicates that `mod` is defined later in the same file, and
        # `:unavailable` indicates that `mod` is involved in cyclic dependency.
        false
      {:error, reason} ->
        raise "Cannot load module #{inspect(mod)} due to reason #{inspect(reason)}"
    end
  end

  if Version.match?(System.version(), ">= 1.10.0") do
    defp suppress_warning_for_undefined_new1(mod_being_compiled, mod) do
      Module.put_attribute(mod_being_compiled, :compile, {:no_warn_undefined, {mod, :new, 1}})
    end
  else
    defp suppress_warning_for_undefined_new1(_, _), do: :ok
  end

  defp has_new1_without_table?(mod, mod_being_compiled) do
    if ensure_compiled_and_loaded?(mod) do
      function_exported?(mod, :new, 1)
    else
      Mix.raise("""
      If #{inspect(mod_being_compiled)} mutually refers to #{inspect(mod)}
      or #{inspect(mod_being_compiled)} is defined inside of #{inspect(mod)},
      try :croma compiler instead of :elixir compiler.
      """)
    end
  end

  defp determine_and_get_modules_to_recompile_recursively(mods_to_recompile \\ []) do
    grouped_mods = StatusTable.list_assumed_modules() |> Enum.group_by(&do_determine/1)
    case grouped_mods do
      # Being determined to false means that assumption made in `has_new1?/1` was wrong.
      # To correct this wrongness, we need to recompile modules in `determined_to_false`.
      %{determined_to_false: determined_to_false} ->
        determine_and_get_modules_to_recompile_recursively(determined_to_false ++ mods_to_recompile)
      _ ->
        grouped_mods
        |> Map.get(:not_determined, [])
        |> Enum.each(&StatusTable.insert_determined(&1, true))
        mods_to_recompile
    end
  end

  defp do_determine(mod) do
    {dynamic?, has_new1?} =
      case EvaluatorTable.evaluate_if_possible(mod) do
        nil       -> {false, {:new, 1} in mod.module_info(:exports)}
        has_new1? -> {true, has_new1?}
      end
    case {dynamic?, has_new1?} do
      {_, false} ->
        StatusTable.insert_determined(mod, false)
        :determined_to_false
      {false, true} ->
        StatusTable.insert_determined(mod, true)
        :determined_to_true
      {true, true} ->
        # We cannot determine to true until no more modules are determined to false.
        # If other modules are determined to false, the next evaluation might result to false.
        :not_determined
    end
  end
end
