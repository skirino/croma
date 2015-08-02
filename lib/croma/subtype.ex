import Croma.Defun
alias Croma.Result, as: R

defmodule Croma.SubtypeOfInt do
  defmacro __using__(opts) do
    quote do
      @min unquote(opts[:min])
      @max unquote(opts[:max])

      if !is_nil(@min) && !is_integer(@min), do: raise ":min must be either nil or integer"
      if !is_nil(@max) && !is_integer(@max), do: raise ":max must be either nil or integer"
      if is_nil(@min) && is_nil(@max)      , do: raise ":min and/or :max must be given"
      if @min && @max && @max < @min       , do: raise ":min must be smaller than :max"

      cond do
        is_nil(@min) ->
          cond do
            @max <= -1 -> @type t :: neg_integer
            true       -> @type t :: integer
          end
          defun validate(term: any) :: R.t(t) do
            i when is_integer(i) and i <= @max -> {:ok, i}
            x                                  -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
          end
        is_nil(@max) ->
          cond do
            1 <= @min -> @type t :: pos_integer
            0 == @min -> @type t :: non_neg_integer
            true      -> @type t :: integer
          end
          defun validate(term: any) :: R.t(t) do
            i when is_integer(i) and @min <= i -> {:ok, i}
            x                                  -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
          end
        true ->
          @type t :: unquote(opts[:min]) .. unquote(opts[:max])
          defun validate(term: any) :: R.t(t) do
            i when is_integer(i) and @min <= i and i <= @max -> {:ok, i}
            x                                                -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
          end
      end
    end
  end
end
