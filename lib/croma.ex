defmodule Croma do
  @moduledoc """
  Utility module to `import` croma macros.

  # Usage:
  Add the following line at the top of source file:

      use Croma

  Note that `Croma.StructCallSyntax` is not imported by default.
  """

  defmacro __using__(_) do
    quote do
      import Croma.Defpt
      import Croma.Defun
      require Croma.Result
      require Croma.List
    end
  end
end
