defmodule Croma.TypeUtil do
  @moduledoc """
  Utilities to work with internal representation of types.
  """

  @primitive_types [
    :pid,
    :port,
    :reference,
    :atom,
    :binary,
    :bitstring,
    :boolean,
    :byte,
    :char,
    :integer,
    :pos_integer,
    :neg_integer,
    :non_neg_integer,
    :float,
    :number,
    :list,
    :tuple,
    :map,
    :fun,
  ]

  @spec resolve_primitive(module, atom, Macro.Env.t) :: {:ok, atom} | :error
  def resolve_primitive(module, name, env) do
    case fetch_types(module) do
      :error -> # No beam file is available
        try do
          [:type, :typep, :opaque]
          |> Enum.flat_map(&fetch_type_info_at_compile_time(module, &1))
          |> Enum.find(&match?({_, {:::, _, [{^name, _, _}, _ast]}, _}, &1))
          |> case do
            nil              -> :error
            {_, type_ast, _} -> destructure_type_expr(module, type_ast, env)
          end
        rescue
          _ -> :error
        end
      {:ok, types} ->
        case Enum.find(types, &match?({_, {^name, _, _}}, &1)) do
          nil            -> :error
          {_, type_expr} -> destructure_type_expr(module, type_to_quoted(type_expr), env)
        end
    end
  end

  defp destructure_type_expr(module, {:::, _, [_lhs, type_ast]}, env) do
    case type_ast do
      {_, _}            -> {:ok, :tuple} # 2-tuple is special in elixir AST
      {:{} , _, _}      -> {:ok, :tuple}
      {:%{}, _, _}      -> {:ok, :map}
      {:%  , _, _}      -> {:ok, :map} # struct
      {t   , _, _}      -> destructure_type_expr2(module, t, env)
      [{:->, _, _}]     -> {:ok, :fun}
      l when is_list(l) -> {:ok, :list}
      _other            -> :error
    end
  end

  defp destructure_type_expr2(module, t, env) do
    case t do
      t when t in @primitive_types -> {:ok, t}
      a when is_atom(a)            -> resolve_primitive(module, a, env)
      {:., _, [mod, n]}            -> resolve_primitive(Macro.expand(mod, env), n, env)
    end
  end

  def list_to_type_union([v    ]), do: v
  def list_to_type_union([h | t]), do: {:|, [], [h, list_to_type_union(t)]}

  #
  # Absorb differences due to Elixir versions
  #
  @elixir_version                      Version.parse!(System.version())
  min_version_not_using_module_attr  = Version.parse!("1.7.0")
  use_module_attr_to_store_typespec? = Version.compare(@elixir_version, min_version_not_using_module_attr) == :lt

  if use_module_attr_to_store_typespec? do
    defp fetch_types(module) do
      case Kernel.Typespec.beam_types(module) do
        nil   -> :error
        types -> {:ok, types}
      end
    end

    defp type_to_quoted(type_expr) do
      Kernel.Typespec.type_to_ast(type_expr)
    end

    def fetch_spec_info_at_compile_time(module) do
      Module.get_attribute(module, :spec)
      |> Enum.map(fn {:spec, x, _} -> x end)
    end

    def fetch_type_info_at_compile_time(module, kind) do
      Module.get_attribute(module, kind)
    end
  else
    defp fetch_types(module) do
      Code.Typespec.fetch_types(module)
    end

    defp type_to_quoted(type_expr) do
      Code.Typespec.type_to_quoted(type_expr)
    end

    @min_version_ets_key_changed Version.parse!("1.7.4")

    def fetch_spec_info_at_compile_time(module) do
      {_set, bag} = :elixir_module.data_tables(module)
      if Version.compare(@elixir_version, @min_version_ets_key_changed) == :lt do
        :ets.lookup(bag, :spec)
        |> Enum.map(fn {:spec, {x, _}} -> x end)
      else
        ets_key = {:accumulate, :spec}
        :ets.lookup(bag, ets_key)
        |> Enum.map(fn {^ets_key, {:spec, x, _}} -> x end)
      end
    end

    def fetch_type_info_at_compile_time(module, kind) do
      {_set, bag} = :elixir_module.data_tables(module)
      ets_key =
        if Version.compare(@elixir_version, @min_version_ets_key_changed) == :lt do
          :type
        else
          {:accumulate, kind}
        end
      :ets.lookup(bag, ets_key)
      |> Enum.map(fn {^ets_key, x} -> x end)
      |> Enum.filter(&match?({^kind, _, _}, &1))
    end
  end
end
