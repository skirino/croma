defmodule Croma do
  defmacro __using__(_) do
    quote do
      import Croma.Defun
    end
  end
end
