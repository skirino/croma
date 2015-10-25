defmodule Croma.Guard do
  @moduledoc """
  Module to work with guard generation (ses `Croma.Defun.defun/2`).
  This module is intended for internal use.
  """

  def make(type_expr, v, caller) do
    case type_expr do
      {:integer        , _, _} -> quote do: is_integer(unquote(v))
      {:pos_integer    , _, _} -> quote do: is_integer(unquote(v)) and unquote(v) > 0
      {:neg_integer    , _, _} -> quote do: is_integer(unquote(v)) and unquote(v) < 0
      {:non_neg_integer, _, _} -> quote do: is_integer(unquote(v)) and unquote(v) >= 0
      {:byte           , _, _} -> quote do: is_integer(unquote(v)) and (unquote(v) in 0..255)
      {:char           , _, _} -> quote do: is_integer(unquote(v)) and (unquote(v) in 0..0x10ffff)
      {:float          , _, _} -> quote do: is_float(unquote(v))
      {:number         , _, _} -> quote do: is_integer(unquote(v)) or is_float(unquote(v))
      {:binary         , _, _} -> quote do: is_binary(unquote(v))
      {:bitstring      , _, _} -> quote do: is_bitstring(unquote(v))
      {:module         , _, _} -> quote do: is_atom(unquote(v)) or is_tuple(unquote(v))
      {:atom           , _, _} -> quote do: is_atom(unquote(v))
      {:node           , _, _} -> quote do: is_atom(unquote(v))
      {:fun            , _, _} -> quote do: is_function(unquote(v))
      {:pid            , _, _} -> quote do: is_pid(unquote(v))
      {:port           , _, _} -> quote do: is_port(unquote(v))
      {:reference      , _, _} -> quote do: is_reference(unquote(v))
      {:char_list      , _, _} -> quote do: is_list(unquote(v))
      {:list           , _, _} -> quote do: is_list(unquote(v))
      {:map            , _, _} -> quote do: is_map(unquote(v))
      {:tuple          , _, _} -> quote do: is_tuple(unquote(v))
      l when is_list(l)        -> quote do: is_list(unquote(v))
      {:%{}            , _, _} -> quote do: is_map(unquote(v))
      {:{}             , _, _} -> quote do: is_tuple(unquote(v))
      {_, _                  } -> quote do: is_tuple(unquote(v)) # tuple with two elements
      {{:., _, [alias_, basename]}, _, _} ->
        case {Macro.expand(alias_, caller), basename} do
          {String         , :t} -> quote do: is_binary(unquote(v))
          {Dict           , :t} -> quote do: is_list(unquote(v)) or is_map(unquote(v))
          {Keyword        , :t} -> quote do: is_list(unquote(v))
          {Croma.Atom     , :t} -> quote do: is_atom(unquote(v))
          {Croma.Boolean  , :t} -> quote do: is_boolean(unquote(v))
          {Croma.Float    , :t} -> quote do: is_float(unquote(v))
          {Croma.Integer  , :t} -> quote do: is_integer(unquote(v))
          {Croma.String   , :t} -> quote do: is_binary(unquote(v))
          {Croma.BitString, :t} -> quote do: is_bitstring(unquote(v))
          {Croma.Function , :t} -> quote do: is_function(unquote(v))
          {Croma.Pid      , :t} -> quote do: is_pid(unquote(v))
          {Croma.Port     , :t} -> quote do: is_port(unquote(v))
          {Croma.Reference, :t} -> quote do: is_reference(unquote(v))
          {Croma.Tuple    , :t} -> quote do: is_tuple(unquote(v))
          {Croma.List     , :t} -> quote do: is_list(unquote(v))
          {Croma.Map      , :t} -> quote do: is_map(unquote(v))
          _ -> raise "cannot generate guard for the given type: #{Macro.to_string type_expr}"
        end
      _ -> raise "cannot generate guard for the given type: #{Macro.to_string type_expr}"
    end
  end
end
