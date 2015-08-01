defmodule Croma.Result do
  use Croma.Monad

  @type t(a) :: {:ok, a} | {:error, any}

  def pure(a), do: {:ok, a}

  def bind({:ok, val}     , f), do: f.(val)
  def bind({:error, _} = e, _), do: e
end
