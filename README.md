Croma
=====

Elixir macro utilities.

[![Build Status](https://travis-ci.org/skirino/croma.svg)](https://travis-ci.org/skirino/croma)
[![Hex.pm](http://img.shields.io/hexpm/v/croma.svg)](https://hex.pm/packages/croma)
[![Hex.pm](http://img.shields.io/hexpm/dt/croma.svg)](https://hex.pm/packages/croma)
[![Github Issues](http://githubbadges.herokuapp.com/skirino/croma/issues.svg)](https://github.com/skirino/croma/issues)
[![Pending Pull-Requests](http://githubbadges.herokuapp.com/skirino/croma/pulls.svg)](https://github.com/skirino/croma/pulls)

## Usage

- Add `:croma` as a mix dependency.
- `$ mix deps.get`
- Add `use Croma` to import all macros defined in this package.
- Hack!

## Defining functions

### `Croma.Defpt.defpt`

Unit-testable `defp` that is simply converted to
- `def` if `Mix.env == :test`,
- `defp` otherwise.

### `Croma.Defun`

Type specification oriented function definition
- Example 1

    ```ex
    import Croma.Defun
    defun f(a: integer, b: String.t) :: String.t do
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
    defun dumbmap(as: [a], f: (a -> b)) :: [b] when a: term, b: term do
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
- Known limitations:
    - Pattern matching against function parameters should use `(param1, param2) when guards -> block` style.
    - Overloaded typespecs are not supported.

## `Croma.Monad`

An interface definition of the monad typeclass.
Modules that `use Croma.Monad` must implement the following interface:
- `@type t(a)` with a type parameter `a`.
- `@spec pure(a: a) :: t(a) when a: any`
- `@spec bind(t(a), (a -> t(b))) :: t(b) when a: any, b: any`

By using the concrete implementations of the above interface, `Croma.Monad` provides the default implementations of the following functions:
- As Functor:
    - `@spec map(t(a), (a -> b)) :: t(b) when a: any, b: any`
- As Applicative:
    - `@spec ap(t(a), t((a -> b))) :: t(b) when a: any, b: any`
    - `@spec sequence([t(a)]) :: t([a]) when a: any`

Note that the order of parameters in `map`/`ap` is different from that of Haskell counterparts, in order to leverage Elixir's pipe operator `|>`.

`Croma.Monad` also provides `bind`-less syntax similar to the Haskell's do-notation.
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

`Corma.Result.t(a)` is defined as `@type t(a) :: {:ok, a} | {:error, any}`.
The module implements `Croma.Monad` interface.
