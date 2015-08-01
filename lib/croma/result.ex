defmodule Croma.Result do
  use Croma.Monad
  import Croma.Defun

  @type t(a) :: {:ok, a} | {:error, any}

  def pure(a), do: {:ok, a}

  def bind({:ok, val}     , f), do: f.(val)
  def bind({:error, _} = e, _), do: e

  defun get(result: t(a)) :: nil | a when a: any do
    {:ok   , val} -> val
    {:error, _  } -> nil
  end

  defun get(result: t(a), default: a) :: a when a: any do
    ({:ok   , val}, _      ) -> val
    ({:error, _  }, default) -> default
  end
end
