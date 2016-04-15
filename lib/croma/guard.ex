defmodule Croma.Guard do
  @moduledoc """
  Module to work with guard generation (see `Croma.Defun.defun/2`).
  This module is intended for internal use.
  """

  def make(type_expr, v, caller) do
    case type_expr do
      {_, _}            -> quote do: is_tuple(unquote(v)) # tuple with two elements
      l when is_list(l) -> quote do: is_list(unquote(v))
      {first, _, _}     -> make_from_tuple3(type_expr, v, caller, first)
      _                 -> error(type_expr)
    end
  end

  defp make_from_tuple3(type_expr, v, caller, first) do
    case first do
      :integer                    -> quote do: is_integer(unquote(v))
      :pos_integer                -> quote do: is_integer(unquote(v)) and unquote(v) > 0
      :neg_integer                -> quote do: is_integer(unquote(v)) and unquote(v) < 0
      :non_neg_integer            -> quote do: is_integer(unquote(v)) and unquote(v) >= 0
      :byte                       -> quote do: is_integer(unquote(v)) and (unquote(v) in 0..255)
      :char                       -> quote do: is_integer(unquote(v)) and (unquote(v) in 0..0x10ffff)
      :float                      -> quote do: is_float(unquote(v))
      :number                     -> quote do: is_integer(unquote(v)) or is_float(unquote(v))
      :binary                     -> quote do: is_binary(unquote(v))
      :bitstring                  -> quote do: is_bitstring(unquote(v))
      :module                     -> quote do: is_atom(unquote(v)) or is_tuple(unquote(v))
      :atom                       -> quote do: is_atom(unquote(v))
      :node                       -> quote do: is_atom(unquote(v))
      :fun                        -> quote do: is_function(unquote(v))
      :pid                        -> quote do: is_pid(unquote(v))
      :port                       -> quote do: is_port(unquote(v))
      :reference                  -> quote do: is_reference(unquote(v))
      :char_list                  -> quote do: is_list(unquote(v))
      :list                       -> quote do: is_list(unquote(v))
      :map                        -> quote do: is_map(unquote(v))
      :tuple                      -> quote do: is_tuple(unquote(v))
      :%{}                        -> quote do: is_map(unquote(v))
      :{}                         -> quote do: is_tuple(unquote(v))
      :<<>>                       -> quote do: is_bitstring(unquote(v))
      {:., _, [alias_, basename]} -> make_with_simplify(type_expr, v, caller, alias_, basename)
      _                           -> error(type_expr)
    end
  end

  defp make_with_simplify(type_expr, v, caller, alias_, basename) do
    mod = Macro.expand(alias_, caller)
    case Croma.TypeUtil.resolve_primitive(mod, basename) do
      {:ok, primitive_type} -> make_from_tuple3(type_expr, v, caller, primitive_type)
      :error                -> error(type_expr)
    end
  end

  defp error(type_expr) do
    raise "cannot generate guard for the given type: #{Macro.to_string(type_expr)}"
  end
end
