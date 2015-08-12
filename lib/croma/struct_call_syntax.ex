defmodule Croma.StructCallSyntax do
  @moduledoc """
  This module provides a new syntax with `~>` operator for calls to functions that take structs as 1st arguments.

  To enable the syntax `import` this module:

      import Croma.StructCallSyntax

  This module is not `import`ed by `use Croma`.
  It is necessary to explicitly `import` this module.

  ## Examples
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

  Note that calling functions with the `~>` syntax involves the following tradeoff:

  - pros
      - Shorter code
      - Flexibility due to dynamic dispatch
  - cons
      - Run-time overhead due to dynamic dispatch
      - Less information available to static analysis tools such as dialyzer
      - Confusions due to new syntax

  It is recommended that you think carefully about the above pros/cons for using this module.
  If all you want is dynamic dispatching based on the receiver's type you can use protocol instead.
  """

  @doc """
  A macro that provides a syntax that resembles method invocations in typical OOP languages.

  The module that defines the target function is extracted from the "receiver" struct (i.e. left hand side of `~>`) at run-time.
  The "receiver" is then passed as the 1st argument to the function.
  """
  defmacro struct ~> {f, _, atom} when is_atom(atom) do # without parameter list
    quote bind_quoted: [struct: struct, f: f] do
      %{__struct__: mod} = struct
      apply(mod, f, [struct])
    end
  end

  defmacro struct ~> {f, _, args} do # with parameter list
    quote bind_quoted: [struct: struct, f: f, args: args] do
      %{__struct__: mod} = struct
      apply(mod, f, [struct | args])
    end
  end
end
