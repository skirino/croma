defmodule Croma.TestCase do
  @moduledoc """
  Module to be `use`d by test modules to make tests a bit shorter.

  `use Croma.TestCase` is almost the same as `use ExUnit.Case`.
  Options passed to `use Croma.TestCase` will also be passed to `use ExUnit.Case`.

  The only difference is that it automatically adds an alias to the test target module,
  which is inferred from the name of the test module.

  ## Example

      defmodule MyProject.SomeModuleTest do
        use Croma.TestCase
        ...
      end

  is equivalent to

      defmodule MyProject.SomeModuleTest do
        use ExUnit.Case
        alias MyProject.SomeModule
        ...
      end

  If you want to pass `as` option to `alias`, use `alias_as`:

      defmodule MyProject.SomeModuleTest do
        use Croma.TestCase, alias_as: M
        ...
      end

  is converted to

      defmodule MyProject.SomeModuleTest do
        use ExUnit.Case
        alias MyProject.SomeModule, as: M
        ...
      end
  """

  defmacro __using__(opts) do
    %Macro.Env{module: current_module} = __CALLER__
    target_module = Atom.to_string(current_module) |> String.replace(~r/Test$/, "") |> List.wrap |> Module.safe_concat
    alias_opts =
      case opts[:alias_as] do
        nil  -> []
        name -> [as: name]
      end
    quote do
      use ExUnit.Case, unquote(opts)
      alias unquote(target_module), unquote(alias_opts)
    end
  end
end
