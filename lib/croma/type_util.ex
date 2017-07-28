defmodule Croma.TypeUtil do
  @moduledoc """
  Utilities to work with internal representation of types.
  """

  alias Kernel.Typespec

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
    case Typespec.beam_types(module) do
      nil -> # No beam file is available
        try do
          [:type, :typep, :opaque]
          |> Enum.flat_map(&Module.get_attribute(module, &1))
          |> Enum.find(&match?({_, {:::, _, [{^name, _, _}, _ast]}, _}, &1))
          |> case do
            nil              -> :error
            {_, type_ast, _} -> destructure_type_expr(module, type_ast, env)
          end
        rescue
          _ -> :error
        end
      types ->
        case Enum.find(types, &match?({_, {^name, _, _}}, &1)) do
          nil            -> :error
          {_, type_expr} -> destructure_type_expr(module, Typespec.type_to_ast(type_expr), env)
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
end
