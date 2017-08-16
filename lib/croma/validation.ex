defmodule Croma.Validation do
  @moduledoc """
  Module for code generation of argument validation (see `Croma.Defun.defun/2`).
  This module is intended for internal use.
  """

  def make(type_expr, v, caller) do
    ast = validation_expr(type_expr, v, caller)
    {name, _, _} = v
    type_string = Macro.to_string(type_expr)
    quote bind_quoted: [name: name, ast: ast, type_string: type_string] do
      case ast do
        true  -> nil
        false -> raise "validation error: #{Atom.to_string(name)} is not a valid #{type_string}"
      end
    end
  end

  defp validation_expr(type_expr, v, caller) do
    case type_expr do
      a when is_atom(a)                -> validation_expr_equal(v, a)
      l when is_list(l)                -> validation_expr_module(v, Croma.List)
      {_, _}                           -> validation_expr_module(v, Croma.Tuple)
      {:t, _, _}                       -> validation_expr_module(v, caller.module)
      {:|, _, [t1, t2]}                -> validation_expr_union(v, t1, t2, caller)
      {{:., _, [mod_alias, :t]}, _, _} -> validation_expr_module(v, replace_elixir_type_module(mod_alias, caller))
      {first, _, _}                    -> validation_expr_module(v, module_for(first, type_expr))
      _                                -> error(type_expr)
    end
  end

  defp module_for(first, type_expr) do
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
  end

  defp validation_expr_module(v, mod) do
    quote bind_quoted: [v: v, mod: mod] do
      Croma.Validation.call_valid1(mod, v)
    end
  end

  defp validation_expr_equal(v, value) do
    quote bind_quoted: [v: v, value: value] do
      v == value
    end
  end

  defp validation_expr_union(v, t1, t2, caller) do
    q1 = validation_expr(t1, v, caller)
    q2 = validation_expr(t2, v, caller)
    quote do
      case unquote(q1) do
        true  -> true
        false -> unquote(q2)
      end
    end
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

  @doc false
  def call_valid1(mod, v) do
    # This should be a simple call to `valid?/1` but for backward compatibility we should fall back to `validate/1`.
    try do
      mod.valid?(v)
    rescue
      e in UndefinedFunctionError ->
        try do
          match?({:ok, _}, mod.validate(v))
        rescue
          UndefinedFunctionError -> reraise(e, System.stacktrace())
        end
    end
  end

  @doc false
  def call_validate1(mod, v) do
    # This function is introduced for backward compatibility of `validate/1`.
    try do
      if mod.valid?(v) do
        {:ok, v}
      else
        {:error, {:invalid_value, [mod]}}
      end
    rescue
      e in UndefinedFunctionError ->
        # For backward compatibility we have to return `validate/1`.
        try do
          mod.validate(v)
        rescue
          UndefinedFunctionError -> reraise(e, System.stacktrace())
        end
    end
  end
end
