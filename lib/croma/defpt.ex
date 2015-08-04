defmodule Croma.Defpt do
  @moduledoc """
  Module that provides `Croma.Defpt.defpt/2` macro.
  """

  @doc """
  Defines a unit-testable private function.
  When `Mix.env == :test`, `defpt` defines a public function and thus it can be freely called from tests.
  Otherwise functions defined by `defpt` become private.
  Usage of this macro is exactly the same as the standard `def` and `defp` macros.

  ## Example
      use Croma

      defmodule M do
        defpt f(x) do
          IO.inspect(x)
        end
      end
  """
  defmacro defpt(call, body \\ nil) do
    if Mix.env == :test do
      quote do: def(unquote(call), unquote(body))
    else
      quote do: defp(unquote(call), unquote(body))
    end
  end
end
