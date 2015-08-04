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

  defun get!(result: t(a)) :: a when a: any do
    {:ok   , val} -> val
    {:error, _  } -> raise "result is not :ok; element not present"
  end

  defun ok?(result: t(a)) :: boolean when a: any do
    {:ok   , _} -> true
    {:error, _} -> false
  end

  defun error?(result: t(a)) :: boolean when a: any do
    !ok?(result)
  end

  defun try(f: (-> a)) :: t(a) when a: any do
    try do
      {:ok, f.()}
    rescue
      e -> {:error, e}
    end
  end
end
