Croma
=====

Elixir macro utilities to make type-based programming easier.
- [API Documentation](http://hexdocs.pm/croma/)
- [Hex package information](https://hex.pm/packages/croma)

[![Hex.pm](http://img.shields.io/hexpm/v/croma.svg)](https://hex.pm/packages/croma)
[![Hex.pm](http://img.shields.io/hexpm/dt/croma.svg)](https://hex.pm/packages/croma)
[![Build Status](https://travis-ci.com/skirino/croma.svg)](https://travis-ci.com/skirino/croma)
[![Coverage Status](https://coveralls.io/repos/github/skirino/croma/badge.svg?branch=master)](https://coveralls.io/github/skirino/croma?branch=master)

## Usage

- Add `:croma` as a mix dependency.
- Run `$ mix deps.get`.
- Add `use Croma` in your source file to import/require macros defined in croma.
- Hack!

## `Croma.Result`

- `Croma.Result.t(a)` is defined as `@type t(a) :: {:ok, a} | {:error, any}`,
  representing a result of computation that can fail.
- This data type is prevalent in Erlang and Elixir world.
  Croma makes it easier to work with `Croma.Result.t(a)` by providing utilities
  such as `get/2`, `get!/1`, `map/2`, `map_error/2`, `bind/2` and `sequence/1`.
- You can also use Haskell-like do-notation to combine results of multiple computations by `m/1` macro.
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
  (The do-notation is implemented by `Croma.Monad`.)

## `Croma.Defun` : Typespec-oriented function definition

- Annotating functions with type specifications is good but sometimes it's a bit tedious
  since one has to repeat some tokens (names of function and arguments, etc.) in `@spec` and `def`.
- `defun/2` macro provides shorthand syntax for defining function with its typespec at once.
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

- In addition to the shorthand syntax explained above, `defun` is able to generate code for runtime type checking:
    - guard: `soma_arg :: g[integer]`
    - validation with `valid?/1` of a type module (see below): `some_arg :: v[SomeType.t]`
- There are also `defunp` and `defunpt` macros for private functions.

## Type modules

- Sometimes you may want to have more fine-grained control of data types than is allowed by [Elixir's typespec](https://hexdocs.pm/elixir/typespecs.html).
  For example you may want to distinguish "arbitrary `String.t`" with "`String.t` that matches a specific regex".
  Croma introduces "type module"s in order to express fine-grained types and enforce type contracts at runtime, with minimal effort.
- Leveraging Elixir's lightweight syntax for defining modules
  (i.e. you can easily make multiple modules within a single source file),
  croma encourages you to define lots of small modules to organize code, especially types, in your Elixir projects.
  Croma expects that a type is defined in its dedicated module, which we call a "type module".
  This way a type can have associated functions within its type module.
- The following definitions in type modules are used by croma:
    - `@type t`
        - The type represented in Elixir's typespec.
    - `valid?(any) :: boolean`
        - Runtime check of whether a given value belongs to the type.
          Used by validation of arguments and return values in `defun`-family of macros.
    - `new(any) :: {:ok, t} | {:error, any}`
        - Tries to convert a given value to a value that belongs to this type.
          Useful e.g. when converting a JSON-parsed value into an Elixir value.
    - `default() :: t`
        - Default value of the type. Must be a constant value. Used as default values of struct fields.

  `@type t` and `valid?/1` are mandatory as they are the raison d'etre of a type module,
  but the others can be omitted.
  And of course you can define any other functions in your type modules as you like.
- You can always define your type modules by directly implementing above functions.
  For simple type modules croma prepares some helpers for you:
    - type modules of built-in types such as `Croma.String`, `Croma.Integer`, etc.
    - helper modules such as `Croma.SubtypeOfString` to define "subtype"s of existing types
    - `Croma.Struct` for structs
    - ad-hoc module generator macros defined in `Croma.TypeGen`

### `Croma.SubtypeOf*`

- You can define your type module for "`String.t` that matches `~r/foo|bar/`" as follows
  (we use `defun` here but you can of course use `@spec` and `def` instead):

    ```ex
    defmodule MyString1 do
      @type t :: String.t
      defun valid?(t :: term) :: boolean do
        s when is_binary(s) -> s =~ ~r/foo|bar/
        _                   -> false
      end
    end
    ```

- However, as this is a common pattern, croma provides a shortcut:

    ```ex
    defmodule MyString2 do
      use Croma.SubtypeOfString, pattern: ~r/foo|bar/
    end
    ```

- There are also `SubtypeOfInt`, `SubtypeOfFloat` and so on.

### `Croma.Struct`

- Defining a type module for a struct can be tedious since you have to check all fields in the struct.
- Using type modules for struct fields, `Croma.Struct` generates definition of type module for a struct.

    ```ex
    defmodule I do
      use Croma.SubtypeOfInt, min: 1, max: 5, default: 1
    end

    defmodule S do
      use Croma.Struct, fields: [
        i: I,
        f: Croma.Float,
      ]
    end

    S.valid?(%S{i: 5, f: 1.5})         # => true
    S.valid?(%S{i: "not_int", f: 1.5}) # => false

    {:ok, s} = S.new(%{f: 1.5})        # => {:ok, %S{i: 1, f: 1.5}}

    # `update/2` is also generated for convenience
    S.update(s, [i: 5])                # => {:ok, %S{i: 5, f: 1.5}}
    S.update(s, %{i: 6})               # => {:error, {:invalid_value, [S, I]}}
    ```

### `Croma.TypeGen`

- Suppose you have a type module `I`, and suppose you want to define a struct that have a field with type `nil | I.t`.
  As nilable fields are common, defining type modules for all nilable fields introduces too much boilerplate code.
- Croma has a set of macros to define this kind of trivial type modules in-line.
  For example you can write as follows using `nilable/1`:

    ```ex
    defmodule S do
      use Croma.Struct, fields: [
        i: Croma.TypeGen.nilable(I),
      ]
    end
    ```

## Notes on backward compatibility

- In `0.7.0` we separated responsibility of `validate/1` into `valid?/1` and `new/1`.
    - Although older type module implementations that define `validate/1` should work as before,
      please migrate to the newer interface by replacing `validate/1` with `valid?/1` and optionally `new/1`.
    - In `0.8.0` we removed support of `validate/1`.
