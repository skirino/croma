Croma
=====

Elixir macro utilities

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
    defun dumbmap(as: [a], f: (a -> b)) :: [b] when a: term, b: `term do
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
- Known limitations:
    - Pattern matching against function parameters should use `(param1, param2) when guards -> block` style.
    - Overloaded typespecs are not supported.
