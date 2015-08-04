defmodule Croma.StructCallSyntax do
  defmacro struct ~> {f, _, atom} when is_atom(atom) do
    quote bind_quoted: [struct: struct, f: f] do
      %{__struct__: mod} = struct
      apply(mod, f, [struct])
    end
  end

  defmacro struct ~> {f, _, args} do
    quote bind_quoted: [struct: struct, f: f, args: args] do
      %{__struct__: mod} = struct
      apply(mod, f, [struct | args])
    end
  end
end
