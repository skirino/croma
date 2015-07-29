defmodule Croma.Defun do
  defmacro defun({:::, _, [fun, ret_type]}, [do: block]) do
    defun_impl(:def, fun, ret_type, [], block)
  end
  defmacro defun({:when, _, [{:::, _, [fun, ret_type]}, type_params]}, [do: block]) do
    defun_impl(:def, fun, ret_type, type_params, block)
  end
  defmacro defunp({:::, _, [fun, ret_type]}, [do: block]) do
    defun_impl(:defp, fun, ret_type, [], block)
  end
  defmacro defunp({:when, _, [{:::, _, [fun, ret_type]}, type_params]}, [do: block]) do
    defun_impl(:defp, fun, ret_type, type_params, block)
  end
  defmacro defunpt({:::, _, [fun, ret_type]}, [do: block]) do
    defun_impl(:defpt, fun, ret_type, [], block)
  end
  defmacro defunpt({:when, _, [{:::, _, [fun, ret_type]}, type_params]}, [do: block]) do
    defun_impl(:defpt, fun, ret_type, type_params, block)
  end

  def defun_impl(def_or_defp, fun, ret_type, type_params, block) do
    spec = typespec(fun, ret_type, type_params)
    bodyless = bodyless_function(def_or_defp, fun)
    fundef = function_definition(def_or_defp, fun, block)
    {:__block__, [], [spec, bodyless, fundef]}
  end

  defp typespec({fname, env, args}, ret_type, []) do
    {:@, env, [
        {:spec, [], [
            {:::, [], [
                {fname, [], arg_types(args)},
                ret_type,
              ]}
          ]}
      ]}
  end
  defp typespec({fname, env, args}, ret_type, type_params) do
    {:@, env, [
        {:spec, [], [
            {:when, [], [
                {:::, [], [
                    {fname, [], arg_types(args)},
                    ret_type,
                  ]},
                type_params,
              ]}
          ]}
      ]}
  end

  defp arg_types(args) do
    (List.first(args || []) || [])
    |> Keyword.values
    |> Enum.map(fn
      {:\\, _, [type, _default]} -> type
      type                       -> type
    end)
  end

  defp bodyless_function(def_or_defp, {fname, env, args}) do
    arg_exprs = (List.first(args || []) || [])
    |> Enum.map(fn
      {name, {:\\, _, [_type, default]}} -> {:\\, [], [{name, [], Elixir}, default]}
      {name, _type}                      -> {name, [], Elixir}
    end)
    {def_or_defp, env, [{fname, env, arg_exprs}]}
  end

  defp function_definition(def_or_defp, {fname, env, args}, block) do
    defs = case block do
      {:__block__, _, multiple_defs} -> multiple_defs
      single_def                     -> List.wrap(single_def)
    end
    if Enum.all?(defs, &pattern_match_expr?/1) do
      clause_defs = Enum.map(defs, &to_clause_definition(def_or_defp, fname, &1))
      {:__block__, env, clause_defs}
    else
      arg_names = (List.first(args || []) || []) |> Keyword.keys |> Enum.map(&({&1, [], nil}))
      {def_or_defp, env, [{fname, env, arg_names}, [do: block]]}
    end
  end

  defp pattern_match_expr?({:->, _, _}), do: true
  defp pattern_match_expr?(_          ), do: false

  defp to_clause_definition(def_or_defp, fname, {:->, env, [args, block]}) do
    case args do
      [{:when, _, when_args}] ->
        fargs = Enum.take(when_args, length(when_args) - 1)
        guards = List.last(when_args)
        when_expr = {:when, [], [{fname, [], fargs}, guards]}
        {def_or_defp, env, [when_expr, [do: block]]}
      _ ->
        {def_or_defp, env, [{fname, env, args}, [do: block]]}
    end
  end
end
