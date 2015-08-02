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

defmodule Croma.SubtypeOfFloat do
  defmacro __using__(opts) do
    quote do
      @min unquote(opts[:min])
      @max unquote(opts[:max])

      if !is_nil(@min) && !is_float(@min), do: raise ":min must be either nil or float"
      if !is_nil(@max) && !is_float(@max), do: raise ":max must be either nil or float"
      if is_nil(@min) && is_nil(@max)    , do: raise ":min and/or :max must be given"
      if @min && @max && @max < @min     , do: raise ":min must be smaller than :max"

      @type t :: float
      cond do
        is_nil(@min) ->
          defun validate(term: any) :: R.t(t) do
            f when is_float(f) and f <= @max -> {:ok, f}
            x                                -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
          end
        is_nil(@max) ->
          defun validate(term: any) :: R.t(t) do
            f when is_float(f) and @min <= f -> {:ok, f}
            x                                -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
          end
        true ->
          defun validate(term: any) :: R.t(t) do
            f when is_float(f) and @min <= f and f <= @max -> {:ok, f}
            x                                              -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
          end
      end
    end
  end
end

defmodule Croma.SubtypeOfString do
  defmacro __using__(opts) do
    quote do
      @pattern unquote(opts[:pattern])
      if !Regex.regex?(@pattern), do: raise ":pattern must be a regex"

      @type t :: String.t

      defun validate(s: term) :: R.t(t) do
        s when is_binary(s) ->
          if Regex.match?(@pattern, s) do
            {:ok, s}
          else
            {:error, "validation error for #{__MODULE__}: #{inspect s}"}
          end
        x -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
      end
    end
  end
end

defmodule Croma.SubtypeOfAtom do
  defp values_as_typespec([v  ]), do: v
  defp values_as_typespec([h|t]), do: {:|, [], [h, values_as_typespec(t)]}

  defmacro __using__(opts) do
    value_atoms = opts[:values] || raise ":values must be present"
    if Enum.empty?(value_atoms), do: raise ":values must be present"
    value_strings      = Enum.map(value_atoms, &Atom.to_string/1)
    values_as_typespec = values_as_typespec(value_atoms)
    quote do
      @type t :: unquote(values_as_typespec)

      defun validate(term: any) :: R.t(t) do
        a when is_atom(a) ->
          if a in unquote(value_atoms) do
            {:ok, a}
          else
            {:error, "validation error for #{__MODULE__}: #{inspect a}"}
          end
        s when is_binary(s) ->
          if s in unquote(value_strings) do
            {:ok, String.to_existing_atom(s)}
          else
            {:error, "validation error for #{__MODULE__}: #{inspect s}"}
          end
        x -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
      end
    end
  end
end
