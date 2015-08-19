import Croma.Defun

[
  {Croma.Atom     , :atom      , :is_atom     },
  {Croma.Boolean  , :boolean   , :is_boolean  },
  {Croma.Float    , :float     , :is_float    },
  {Croma.Integer  , :integer   , :is_integer  },
  {Croma.String   , :"String.t", :is_binary   },
  {Croma.BitString, :bitstring , :is_bitstring},
  {Croma.Function , :function  , :is_function },
  {Croma.Pid      , :pid       , :is_pid      },
  {Croma.Port     , :port      , :is_port     },
  {Croma.Reference, :reference , :is_reference},
  {Croma.Tuple    , :tuple     , :is_tuple    },
  {Croma.List     , :list      , :is_list     },
  {Croma.Map      , :map       , :is_map      },
]
|> Enum.each fn {mod, builtin_type, pred} ->
  defmodule mod do
    @moduledoc """
    Module that represents the Elixir's built-in #{builtin_type} type.
    Intended to be used with other parts of croma to express #{builtin_type} variables.
    """

    @type t :: unquote(builtin_type)

    @doc """
    Simply checks the argument's type using `#{pred}/1` and returns a `Croma.Result`.
    """
    defun validate(value: term) :: Croma.Result.t(t) do
      b when unquote(pred)(b) -> {:ok, b}
      _                       -> {:error, {:invalid_value, [__MODULE__]}}
    end
  end
end
