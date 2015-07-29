defmodule Croma do
  defmacro __using__(_) do
    quote do
      import Croma.Defpt
      import Croma.Defun
    end
  end
end
