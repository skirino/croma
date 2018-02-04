defmodule Croma.DebugAssertError do
  defexception [:message]
end

defmodule Croma.DebugAssert do
  @doc """
  Ensures that the given expression evaluates to some truthy value at runtime and raises otherwise.

  This is intended to be used as debugging purposes: crash immediately when any logic error is found,
  similar to `assert()` in C.
  However note that, unlike C, crash of the currently running process does not necessarily stop execution of the program.

  Runtime checks by `debug_assert/2` can be disabled by setting application config during compilation.

      config :croma, [
        debug_assert: false
      ]

  The passed expression should be side effect free in order to preserve code semantics when disabled.
  """
  defmacro debug_assert(expr, message \\ "") do
    if Application.get_env(:croma, :debug_assert, true) do
      %Macro.Env{file: file, line: line} = __CALLER__
      prefix = "#{file}:#{line} `#{Macro.to_string(expr)}` is not truthy!"
      quote bind_quoted: [expr: expr, prefix: prefix, messag: message] do
        unless expr do
          raise Croma.DebugAssertError, message: "#{prefix} #{messag}"
        end
      end
    else
      nil
    end
  end
end
