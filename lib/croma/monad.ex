defmodule Croma.Monad do
  # Here I don't use `Behaviour` and `defcallback`
  # since it seems that Elixir's behaviour and typespecs don't provide a way to refer to a type
  # that will be defined in the module that use this module.
  defmacro __using__(_) do
    quote do
      # functions that must be implemented in each user module
      @spec pure(a: a) :: t(a) when a: any
      @spec bind(t(a), (a -> t(b))) :: t(b) when a: any, b: any

      # default implementation of Functor
      @spec map(t(a), (a -> b)) :: t(b) when a: any, b: any
      def map(ma, f) do
        bind(ma, fn(a) -> pure f.(a) end)
      end

      # default implementation of Applicative
      @spec ap(t(a), t((a -> b))) :: t(b) when a: any, b: any
      def ap(ma, mf) do
        bind(mf, fn f -> map(ma, f) end)
      end

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

      # Hakell-like do-notation for monads
      defmacro m(do: block) do
        case block do
          {:__block__, _, unwrapped} -> Croma.Monad.DoImpl.do_expr(__MODULE__, unwrapped)
          _                          -> Croma.Monad.DoImpl.do_expr(__MODULE__, [block])
        end
      end
    end
  end

  defmodule DoImpl do
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
