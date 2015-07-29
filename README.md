Croma
=====

Elixir macro utilities.

[![Build Status](https://travis-ci.org/skirino/croma.svg)](https://travis-ci.org/skirino/croma)
[![Hex.pm](http://img.shields.io/hexpm/v/croma.svg)](https://hex.pm/packages/croma)
[![Hex.pm](http://img.shields.io/hexpm/dt/croma.svg)](https://hex.pm/packages/croma)
[![Github Issues](http://githubbadges.herokuapp.com/skirino/croma/issues.svg)](https://github.com/skirino/croma/issues)
[![Pending Pull-Requests](http://githubbadges.herokuapp.com/skirino/croma/pulls.svg)](https://github.com/skirino/croma/pulls)

## `Croma.Defpt`

Unit-testable `defp` that is converted to
- `defp` if `Mix.env == :test`,
- `def` otherwise.

## `Croma.Defun`

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
