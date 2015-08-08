import Croma.Defun
alias Croma.Result, as: R

defmodule Croma.Boolean do
  @moduledoc """
  Module that represents the built-in boolean type.
  Intended to be used with `Croma.Struct` to define structs that have boolean fields.
  """

  @type t :: boolean

  defun validate(value: term) :: R.t(t) do
    b when is_boolean(b) -> {:ok, b}
    x                    -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
  end
end
