import Croma.Defun

defmodule Croma.BuiltinType do
  @moduledoc false

  @type_infos [
    {Croma.Atom         , "atom"           , (quote do: atom           ), (quote do: is_atom     (var!(x)))},
    {Croma.Boolean      , "boolean"        , (quote do: boolean        ), (quote do: is_boolean  (var!(x)))},
    {Croma.Float        , "float"          , (quote do: float          ), (quote do: is_float    (var!(x)))},
    {Croma.Integer      , "integer"        , (quote do: integer        ), (quote do: is_integer  (var!(x)))},
    {Croma.Number       , "number"         , (quote do: number         ), (quote do: is_number   (var!(x)))},
    {Croma.String       , "String.t"       , (quote do: String.t       ), (quote do: is_binary   (var!(x)))},
    {Croma.Binary       , "binary"         , (quote do: binary         ), (quote do: is_binary   (var!(x)))},
    {Croma.BitString    , "bitstring"      , (quote do: bitstring      ), (quote do: is_bitstring(var!(x)))},
    {Croma.Function     , "function"       , (quote do: function       ), (quote do: is_function (var!(x)))},
    {Croma.Pid          , "pid"            , (quote do: pid            ), (quote do: is_pid      (var!(x)))},
    {Croma.Port         , "port"           , (quote do: port           ), (quote do: is_port     (var!(x)))},
    {Croma.Reference    , "reference"      , (quote do: reference      ), (quote do: is_reference(var!(x)))},
    {Croma.Tuple        , "tuple"          , (quote do: tuple          ), (quote do: is_tuple    (var!(x)))},
    {Croma.List         , "list"           , (quote do: list           ), (quote do: is_list     (var!(x)))},
    {Croma.Map          , "map"            , (quote do: map            ), (quote do: is_map      (var!(x)))},
    {Croma.Byte         , "byte"           , (quote do: byte           ), (quote do: var!(x) in 0..255)},
    {Croma.Char         , "char"           , (quote do: char           ), (quote do: var!(x) in 0..0x10ffff)},
    {Croma.PosInteger   , "pos_integer"    , (quote do: pos_integer    ), (quote do: is_integer(var!(x)) and var!(x) >  0)},
    {Croma.NegInteger   , "neg_integer"    , (quote do: neg_integer    ), (quote do: is_integer(var!(x)) and var!(x) <  0)},
    {Croma.NonNegInteger, "non_neg_integer", (quote do: non_neg_integer), (quote do: is_integer(var!(x)) and var!(x) >= 0)},
  ]

  def type_infos(), do: @type_infos
  def all() do
    Enum.map(@type_infos, fn {m, _, _, _} -> m end)
  end
end

Croma.BuiltinType.type_infos() |> Enum.each(fn {mod, type_name, type_expr, guard_expr} ->
  defmodule mod do
    @moduledoc """
    Module that represents the Elixir's built-in #{type_name} type.
    Intended to be used with other parts of croma to express #{type_name} variables.
    """

    @type t :: unquote(type_expr)

    @doc """
    Simply checks the argument's type using `#{Macro.to_string(guard_expr)}`.
    """
    defun valid?(value :: term) :: boolean do
      x when unquote(guard_expr) -> true
      _                          -> false
    end
  end
end)

defmodule Croma.Any do
  @moduledoc """
  Module that represents any Elixir term.
  """

  @type t :: any

  @doc """
  Always returns `true`
  Intended to be used with other parts of croma to express variables with `any` type.
  """
  defun valid?(_value :: term) :: boolean do
    true
  end
end
