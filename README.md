Croma
=====

Elixir macro utilities to make type-based programming easier.
- [API Documentation](http://hexdocs.pm/croma/)
- [Hex package information](https://hex.pm/packages/croma)

[![Hex.pm](http://img.shields.io/hexpm/v/croma.svg)](https://hex.pm/packages/croma)
[![Hex.pm](http://img.shields.io/hexpm/dt/croma.svg)](https://hex.pm/packages/croma)
[![Build Status](https://travis-ci.org/skirino/croma.svg)](https://travis-ci.org/skirino/croma)
[![Coverage Status](https://coveralls.io/repos/skirino/croma/badge.png?branch=master)](https://coveralls.io/r/skirino/croma?branch=master)

## Usage

- Add `:croma` as a mix dependency.
- `$ mix deps.get`
- Add `use Croma` to import macros defined in this package.
- Hack!

## `Croma.Result`

- `Corma.Result.t(a)` is defined as `@type t(a) :: {:ok, a} | {:error, any}`.
- Utilities such as `get/2`, `get!/1`, `map/2`, `map_error/2`, `bind/2` and `sequence/1` are provided.
- This module also implements `Croma.Monad` interface and thus
  you can use Haskell-like do-notation to combine results of multiple computations that may fail.
  For example,

    ```ex
    Croma.Result.m do
      x <- {:ok, 1}
      y <- {:ok, 2}
      pure x + y
    end
    ```

  is converted to

    ```ex
    Croma.Result.bind(mx, fn x ->
      Croma.Result.bind(my, fn y ->
        Croma.Result.pure(x + y)
      end)
    end)
    ```

  and is evaluated to `{:ok, 3}`.

## Type modules

Leveraging Elixir's lightweight syntax for defining modules
(i.e. you can easily define multiple modules within a single source file),
croma encourages you to define lots of small modules to organize code, especially types, in your Elixir projects.
Many features of croma expect that a type is defined in its dedicated module, which we call hereafter as "type module".
This way a type can have associated functions within its type module.
The following definitions in type modules are used by croma:

- `@type t`
    - The type this type module represents. Used in typespecs.
- `valid?(any) :: boolean`
    - Runtime check of whether a given value belongs to the type.
      Used by validation of arguments and return values in `defun`-family of macros.
- `new(any) :: {:ok, t} | {:error, any}`
    - Tries to convert a given value to a value that belongs to this type.
      Useful e.g. when converting a JSON value into an Elixir value.
- `default() :: t`
    - Default value of the module. Used as default values of struct fields.

`@type t` is mandatory as it's the raison d'etre of a type module,
but the others can be omitted if you don't use specific features of croma.
And of course you can define any other functions in your type modules as you like.

You can always define your type modules by directly implementing above functions.
For simple type modules croma prepares some helpers for you:
    - Type modules of built-in types such as `Croma.String`, `Croma.Integer`, etc.
    - Helper modules such as `Croma.SubtypeOfString` to define "subtype"s of existing types
    - Ad-hoc module generator macros defined in `Croma.TypeGen`

## `Croma.Struct` : Type module of a struct from type modules of its fields

- Utility module to define structs with type specification and validation functions.

    ```ex
    iex> defmodule I do
    ...>   @type t :: integer
    ...>   def valid?(i) when is_integer(i), do: true
    ...>   def valid?(_), do: false
    ...>   def default(), do: 0
    ...> end

    ...> defmodule S do
    ...>   use Croma.Struct, fields: [i: I]
    ...> end

    ...> S.valid?(%S{i: 5})
    true

    ...> S.valid?(%S{i: "not_an_integer"})
    false

    ...> {:ok, s} = S.new([])
    {:ok, %S{i: 0}}

    ...> S.update(s, [i: 2])
    {:ok, %S{i: 2}}

    ...> S.update(s, %{"i" => "not_an_integer"})
    {:error, {:invalid_value, [S, I]}}
    ```

## `Croma.Defun` : Typespec-oriented function definition

- `defun/2` macro provides shorthand syntax for defining function and annotating its typespec at once.
    - Example 1

        ```ex
        use Croma
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
    - Example 2 (multi-clause syntax)

        ```ex
        use Croma
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

- In addition to the shorthand syntax, `defun` is able to generate code for runtime type checking:
    - guard: `soma_arg :: g[integer]`
    - validation with type module's `valid?/1`: `some_arg :: v[SomeType.t]`
- There are also `defunp` and `defunpt` macros for private functions.
- Limitations:
    - Pattern matching against function parameters must use `(param1, param2) when guards -> block` syntax.
    - Overloaded typespecs are not supported.
    - Using unquote fragment in parameter list is not fully supported.
