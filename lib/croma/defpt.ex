defmodule Croma.Defpt do
  defmacro defpt(call, body \\ nil) do
    if Mix.env == :test do
      quote do: def(unquote(call), unquote(body))
    else
      quote do: defp(unquote(call), unquote(body))
    end
  end
end
