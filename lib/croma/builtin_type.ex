import Croma.Defun

defmodule Croma.BuiltinType do
  @moduledoc false

  @type_infos [
    {Croma.Atom     , :is_atom     , "atom"     , quote do: atom     },
    {Croma.Boolean  , :is_boolean  , "boolean"  , quote do: boolean  },
    {Croma.Float    , :is_float    , "float"    , quote do: float    },
    {Croma.Integer  , :is_integer  , "integer"  , quote do: integer  },
    {Croma.String   , :is_binary   , "String.t" , quote do: String.t },
    {Croma.BitString, :is_bitstring, "bitstring", quote do: bitstring},
    {Croma.Function , :is_function , "function" , quote do: function },
    {Croma.Pid      , :is_pid      , "pid"      , quote do: pid      },
    {Croma.Port     , :is_port     , "port"     , quote do: port     },
    {Croma.Reference, :is_reference, "reference", quote do: reference},
    {Croma.Tuple    , :is_tuple    , "tuple"    , quote do: tuple    },
    {Croma.List     , :is_list     , "list"     , quote do: list     },
    {Croma.Map      , :is_map      , "map"      , quote do: map      },
  ]

  def type_infos, do: @type_infos
  def all do
    Enum.map(@type_infos, fn {m, _, _, _} -> m end)
  end
end

Croma.BuiltinType.type_infos |> Enum.each fn {mod, pred, type_name, type_expr} ->
  defmodule mod do
    @moduledoc """
    Module that represents the Elixir's built-in #{type_name} type.
    Intended to be used with other parts of croma to express #{type_name} variables.
    """

    @type t :: unquote(type_expr)

    @doc """
    Simply checks the argument's type using `#{pred}/1` and returns a `Croma.Result`.
    """
    defun validate(value :: term) :: Croma.Result.t(t) do
      b when unquote(pred)(b) -> {:ok, b}
      _                       -> {:error, {:invalid_value, [__MODULE__]}}
    end
  end
end

defmodule Croma.Any do
  @moduledoc """
  Module that represents any Elixir term.
  """

  @type t :: any

  @doc """
  Wraps the argument into `{:ok, value}`.
  Intended to be used with other parts of croma to express variables with `any` type.
  """
  defun validate(value :: term) :: {:ok, t} do
    {:ok, value}
  end
end
