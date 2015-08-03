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

      @default unquote(opts[:default])
      if @default do
        if !is_integer(@default)           , do: raise ":default must be an integer"
        if !is_nil(@min) && @default < @min, do: raise ":default must be a valid value"
        if !is_nil(@max) && @max < @default, do: raise ":default must be a valid value"
        defun default() :: t, do: @default
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

      @default unquote(opts[:default])
      if @default do
        if !is_float(@default)             , do: raise ":default must be a float"
        if !is_nil(@min) && @default < @min, do: raise ":default must be a valid value"
        if !is_nil(@max) && @max < @default, do: raise ":default must be a valid value"
        defun default() :: t, do: @default
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

      @default unquote(opts[:default])
      if @default do
        if !Regex.match?(@pattern, @default), do: raise ":default must be a valid string"
        defun default() :: t, do: @default
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

      @default unquote(opts[:default])
      if @default do
        unless @default in unquote(value_atoms), do: raise ":default must be a valid atom"
        defun default() :: t, do: @default
      end
    end
  end
end

defmodule Croma.SubtypeOfList do
  defmacro __using__(opts) do
    mod = opts[:elem_module] || raise ":elem_module must be given"
    quote do
      @type t :: [unquote(mod).t]

      defun validate(term: any) :: R.t(t) do
        l when is_list(l) ->
          require R
          R.m do
            elems <- Enum.map(l, &unquote(mod).validate/1) |> R.sequence
            if valid_length?(length(elems)) do
              {:ok, elems}
            else
              {:error, "validation error for #{__MODULE__}: #{inspect l}"}
            end
          end
        x -> {:error, "validation error for #{__MODULE__}: #{inspect x}"}
      end

      @min unquote(opts[:min_length])
      @max unquote(opts[:max_length])
      cond do
        is_nil(@min) && is_nil(@max) ->
          defp valid_length?(_), do: true
        is_nil(@min) ->
          defp valid_length?(len), do: len <= @max
        is_nil(@max) ->
          defp valid_length?(len), do: @min <= len
        true ->
          defp valid_length?(len), do: @min <= len && len <= @max
      end
    end
  end
end
