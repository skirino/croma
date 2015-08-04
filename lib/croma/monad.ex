defmodule Croma.Monad do
  @moduledoc """
  This module defines an interface for [monad](https://en.wikipedia.org/wiki/Monad).

  Modules that `use` this module must provide concrete implementations of the following:

  - `@type t(a)`
  - `@spec pure(a: a) :: t(a) when a: any`
  - `@spec bind(t(a), (a -> t(b))) :: t(b) when a: any, b: any`

  Using concrete implementations of the above interfaces, this module generates default implementations of some functions/macros.
  See `Croma.Result` for the generated functions/macros.
  """

  # Here I don't use `Behaviour` and `defcallback`
  # since it seems that Elixir's behaviour and typespecs don't provide a way to refer to a type
  # that will be defined in the module that use this module.
  defmacro __using__(_) do
    quote do
      @spec pure(a: a) :: t(a) when a: any
      @spec bind(t(a), (a -> t(b))) :: t(b) when a: any, b: any

      @doc """
      Default implementation of Functor's `fmap` operation.
      Modules that implement `Croma.Monad` may override this default implementation.
      Note that the order of arguments is different from the Haskell counterpart, in order to leverage Elixir's pipe operator `|>`.
      """
      @spec map(t(a), (a -> b)) :: t(b) when a: any, b: any
      def map(ma, f) do
        bind(ma, fn(a) -> pure f.(a) end)
      end

      @doc """
      Default implementation of Applicative's `ap` operation.
      Modules that implement `Croma.Monad` may override this default implementation.
      Note that the order of arguments is different from the Haskell counterpart, in order to leverage Elixir's pipe operator `|>`.
      """
      @spec ap(t(a), t((a -> b))) :: t(b) when a: any, b: any
      def ap(ma, mf) do
        bind(mf, fn f -> map(ma, f) end)
      end

      @doc """
      Converts the given list of monadic (to be precise, applicative) objects into a monadic object that contains a single list.
      Modules that implement `Croma.Monad` may override this default implementation.

      ## Examples (using Croma.Result)
          iex> Croma.Result.sequence([{:ok, 1}, {:ok, 2}, {:ok, 3}])
          {:ok, [1, 2, 3]}

          iex> Croma.Result.sequence([{:ok, 1}, {:error, :foo}, {:ok, 3}])
          {:error, :foo}
      """
      @spec sequence([t(a)]) :: t([a]) when a: any
      def sequence([]), do: pure []
      def sequence([h | t]) do
        # Note that current implementation is not tail-recursive
        bind(h, fn(a) ->
          bind(sequence(t), fn(as) ->
            pure [a | as]
          end)
        end)
      end

      defoverridable [
        map:      2,
        ap:       2,
        sequence: 1,
      ]

      @doc """
      A macro that provides Hakell-like do-notation.

      ## Examples
          MonadImpl.m do
            x <- mx
            y <- my
            pure f(x, y)
          end

      is expanded to

          MonadImpl.bind(mx, fn x ->
            MonadImpl.bind(my, fn y ->
              MonadImpl.pure f(x, y)
            end)
          end)
      """
      defmacro m(do: block) do
        case block do
          {:__block__, _, unwrapped} -> Croma.Monad.DoImpl.do_expr(__MODULE__, unwrapped)
          _                          -> Croma.Monad.DoImpl.do_expr(__MODULE__, [block])
        end
      end
    end
  end

  defmodule DoImpl do
    @moduledoc false

    def do_expr(module, [{:<-, _, [l, r]}]) do
      quote do
        unquote(module).bind(unquote(r), fn(unquote(l)) -> unquote(l) end)
      end
    end
    def do_expr(module, [{:<-, _, [l, r]} | rest]) do
      quote do
        unquote(module).bind(unquote(r), fn(unquote(l)) -> unquote(do_expr(module, rest)) end)
      end
    end
    def do_expr(module, [expr]) do
      case expr do
        {:pure, n, args} -> {{:., n, [module, :pure]}, n, args}
        _                  -> expr
      end
    end
    def do_expr(module, [expr | rest]) do
      quote do
        unquote(expr)
        unquote(do_expr(module, rest))
      end
    end
  end
end
