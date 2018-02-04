defmodule Croma do
  @moduledoc """
  Utility module to `import` croma macros.

  # Usage:
  Add the following line at the top of source file:

      use Croma
  """

  defmacro __using__(_) do
    quote do
      import Croma.Defpt
      import Croma.Defun
      import Croma.DebugAssert
      require Croma.TypeGen
      require Croma.Result
      require Croma.ListMonad
      :ok
    end
  end
end
