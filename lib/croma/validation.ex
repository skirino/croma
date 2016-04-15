defmodule Croma.Validation do
  @moduledoc """
  Module for code generation of argument validation (see `Croma.Defun.defun/2`).
  This module is intended for internal use.
  """

  def make(type_expr, {name, _, _} = v, _caller) do
    case type_expr do
      {:t, meta, _} ->
        rhs = quote bind_quoted: [name: name, v: v] do
          case validate(v) do
            {:ok   , value } -> value
            {:error, reason} -> raise "validation error for #{Atom.to_string(name)}: #{inspect reason}"
          end
        end
        {:=, meta, [v, rhs]}
      {{:., meta, [mod_alias, :t]}, _, _} ->
        rhs = quote bind_quoted: [name: name, v: v, mod: mod_alias] do
          case mod.validate(v) do
            {:ok   , value } -> value
            {:error, reason} -> raise "validation error for #{Atom.to_string(name)}: #{inspect reason}"
          end
        end
        {:=, meta, [v, rhs]}
      _ -> raise "cannot generate validation code for the given type: #{Macro.to_string(type_expr)}"
    end
  end
end
