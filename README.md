Croma
=====

Elixir macro utilities.
- [API Documentation](http://hexdocs.pm/croma/)
- [Hex package information](https://hex.pm/packages/croma)

[![Hex.pm](http://img.shields.io/hexpm/v/croma.svg)](https://hex.pm/packages/croma)
[![Hex.pm](http://img.shields.io/hexpm/dt/croma.svg)](https://hex.pm/packages/croma)
[![Build Status](https://travis-ci.org/skirino/croma.svg)](https://travis-ci.org/skirino/croma)
[![Coverage Status](https://coveralls.io/repos/skirino/croma/badge.png?branch=master)](https://coveralls.io/r/skirino/croma?branch=master)
[![Inline docs](http://inch-ci.org/github/skirino/croma.svg)](http://inch-ci.org/github/skirino/croma)
[![Github Issues](http://githubbadges.herokuapp.com/skirino/croma/issues.svg)](https://github.com/skirino/croma/issues)
[![Pending Pull-Requests](http://githubbadges.herokuapp.com/skirino/croma/pulls.svg)](https://github.com/skirino/croma/pulls)

## Usage

- Add `:croma` as a mix dependency.
- `$ mix deps.get`
- Add `use Croma` to import macros defined in this package.
- Hack!

## Defining functions

### `Croma.Defpt.defpt`

- Unit-testable `defp` that is simply converted to
    - `def` if `Mix.env == :test`,
    - `defp` otherwise.
- This is particularly useful when e.g. you want to test your module's internal logic
  which is implemented as a pure function and thus easily testable.

### `Croma.Defun`

- Type specification oriented function definition
    - Example 1

        ```ex
        import Croma.Defun
        defun f(a :: integer, b :: String.t) :: String.t do
          "#{a} #{b}"
        end
        ```
    is expanded to
        ```ex
        @spec f(integer, String.t) :: String.t
        def f(a, b) do
          "#{a} #{b}"
        end
        ```
    - Example 2

        ```ex
        import Croma.Defun
        defun dumbmap(as :: [a], f :: (a -> b)) :: [b] when a: term, b: term do
          ([]     , _) -> []
          ([h | t], f) -> [f.(h) | dumbmap(t, f)]
        end
        ```
    is expanded to
        ```ex
        @spec dumbmap([a], (a -> b)) :: [b] when a: term, b: term
        def dumbmap(as, f)
        def dumbmap([], _) do
          []
        end
        def dumbmap([h | t], f) do
          [f.(h) | dumbmap(t, f)]
        end
        ```
    - There are also `defunp` and `defunpt` macros for private functions.
    - Limitations:
        - Pattern matching against function parameters should use `(param1, param2) when guards -> block` style.
        - Overloaded typespecs are not supported.
        - Using unquote fragment in parameter list is not fully supported.

## `Croma.Monad`

- An interface definition of the monad typeclass.
- Modules that `use Croma.Monad` must implement the following interface:
    - `@type t(a)` with a type parameter `a`.
    - `@spec pure(a) :: t(a) when a: any`
    - `@spec bind(t(a), (a -> t(b))) :: t(b) when a: any, b: any`
- By using the concrete implementations of the above interface, `Croma.Monad` provides the default implementations of the following functions:
    - As Functor:
        - `@spec map(t(a), (a -> b)) :: t(b) when a: any, b: any`
    - As Applicative:
        - `@spec ap(t(a), t((a -> b))) :: t(b) when a: any, b: any`
        - `@spec sequence([t(a)]) :: t([a]) when a: any`
- Note that the order of parameters in `map`/`ap` is different from that of Haskell counterparts, in order to leverage Elixir's pipe operator `|>`.
- `Croma.Monad` also provides `bind`-less syntax similar to Haskell's do-notation.
For example,

    ```ex
    MonadImpl.m do
      x <- mx
      y <- my
      pure f(x, y)
    end
    ```
is converted to
    ```ex
    MonadImpl.bind(mx, fn x ->
      MonadImpl.bind(my, fn y ->
        MonadImpl.pure f(x, y)
      end)
    end)
    ```

### `Croma.Result`

- `Corma.Result.t(a)` is defined as `@type t(a) :: {:ok, a} | {:error, any}`.
This module implements `Croma.Monad` interface.

### `Croma.ListMonad`

- Implementation of `Croma.Monad` for lists.
`Croma.ListMonad.t(a)` is just an alias to `[a]`.



## Working with structs

### `Croma.Struct`

- Utility module to define structs with type specification and validation functions.

    ```ex
    iex> defmodule I do
    ...>   @type t :: integer
    ...>   def validate(i) when is_integer(i), do: {:ok, i}
    ...>   def validate(_), do: {:error, {:invalid_value, [__MODULE__]}}
    ...>   def default, do: 0
    ...> end

    ...> defmodule S do
    ...>   use Croma.Struct, fields: [i: I]
    ...> end

    ...> S.validate([i: 5])
    {:ok, %S{i: 5}}

    ...> S.validate(%{i: "not_an_integer"})
    {:error, {:invalid_value, [S, I]}}

    ...> {:ok, s} = S.new([])
    {:ok, %S{i: 0}}

    ...> S.update(s, [i: 2])
    {:ok, %S{i: 2}}

    ...> S.update(s, %{"i" => "not_an_integer"})
    {:error, {:invalid_value, [S, I]}}
    ```

- Some helper modules for "per-field module"s that are passed as options to `use Croma.Struct` (`I` in the above example) are available.
    - Wrappers of built-in types such as `Croma.String`, `Croma.Integer`, etc.
    - Utility modules such as `Croma.SubtypeOfString` to define "subtypes" of existing types.
    - Ad-hoc module generators defined in `Croma.TypeGen`.

### `Croma.StructCallSyntax`

- A new syntax (which uses `~>` operator) for calls to functions that take structs as 1st arguments.

    ```ex
    iex> defmodule S do
    ...>   defstruct [:a, :b]
    ...>   def f(s, i) do
    ...>     s.a + s.b + i
    ...>   end
    ...> end

    ...> import Croma.StructCallSyntax
    ...> s = %S{a: 1, b: 2}
    ...> s~>f(3)              # => S.f(s, 3)
    6
    ```
