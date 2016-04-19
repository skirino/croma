defmodule Croma.Validation do
  @moduledoc """
  Module for code generation of argument validation (see `Croma.Defun.defun/2`).
  This module is intended for internal use.
  """

  def make(type_expr, v, caller) do
    case type_expr do
      l when is_list(l)                   -> validation_expr(v, [], Croma.List)
      {_, _}                              -> validation_expr(v, [], Croma.Tuple)
      {:t, meta, _}                       -> validation_expr(v, meta)
      {{:., meta, [mod_alias, :t]}, _, _} -> validation_expr(v, meta, replace_elixir_type_module(mod_alias, caller))
      {first, meta, _}                    -> make_from_tuple3(type_expr, v, first, meta)
      _                                   -> error(type_expr)
    end
  end

  defp make_from_tuple3(type_expr, v, first, meta) do
    mod =
      case first do
        :integer         -> Croma.Integer
        :pos_integer     -> Croma.PosInteger
        :neg_integer     -> Croma.NeInteger
        :non_neg_integer -> Croma.NonNegInteger
        :boolean         -> Croma.Boolean
        :byte            -> Croma.Byte
        :char            -> Croma.Char
        :float           -> Croma.Float
        :number          -> Croma.Number
        :binary          -> Croma.Binary
        :bitstring       -> Croma.BitString
        :module          -> Croma.Atom
        :atom            -> Croma.Atom
        :node            -> Croma.Atom
        :fun             -> Croma.Function
        :pid             -> Croma.Pid
        :port            -> Croma.Port
        :reference       -> Croma.Reference
        :char_list       -> Croma.List
        :list            -> Croma.List
        :map             -> Croma.Map
        :tuple           -> Croma.Tuple
        :%{}             -> Croma.Map
        :{}              -> Croma.Tuple
        :<<>>            -> Croma.BitString
        _                -> error(type_expr)
      end
    validation_expr(v, meta, mod)
  end

  defp validation_expr(v, meta) do
    {name, _, _} = v
    rhs = quote bind_quoted: [name: name, v: v] do
      case validate(v) do
        {:ok   , value } -> value
        {:error, reason} -> raise "validation error for #{Atom.to_string(name)}: #{inspect reason}"
      end
    end
    {:=, meta, [v, rhs]}
  end
  defp validation_expr(v, meta, mod) do
    {name, _, _} = v
    rhs = quote bind_quoted: [name: name, v: v, mod: mod] do
      case mod.validate(v) do
        {:ok   , value } -> value
        {:error, reason} -> raise "validation error for #{Atom.to_string(name)}: #{inspect reason}"
      end
    end
    {:=, meta, [v, rhs]}
  end

  defp replace_elixir_type_module(mod_alias, caller) do
    mod = Macro.expand(mod_alias, caller)
    case mod do
      String -> Croma.String
      _      -> mod
    end
  end

  defp error(type_expr) do
    raise "cannot generate validation code for the given type: #{Macro.to_string(type_expr)}"
  end
end
