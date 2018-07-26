if Mix.env() == :test do
  defmodule Croma.Testonly do
    alias String, as: S
    @type   b1 :: String.t
    @typep  b2 :: S.t
    @opaque b3 :: b2

    @type l1 :: []
    @type l2 :: [integer]
    @type l3 :: list
    @type l4 :: list(String.t)

    @type t0 :: {}
    @type t1 :: {atom}
    @type t2 :: {atom, integer}
    @type t3 :: {String.t, float, binary}
    @type t4 :: tuple

    @type m1 :: %{}
    @type m2 :: %{String.t => String.t}
    @type m3 :: map
    @type m4 :: %Regex{}

    @type f1 :: fun
    @type f2 :: ((integer, atom) -> String.t)

    @type u :: :a | :b | :c

    [:type, :typep, :opaque]
    |> Enum.flat_map(fn t -> Croma.TypeUtil.fetch_type_info_at_compile_time(__MODULE__, t) end)
    |> Enum.each(fn {_, {:::, _, [{name, _, _} | _]}, _} ->
      t = Croma.TypeUtil.resolve_primitive(__MODULE__, name, __ENV__)
      def unquote(name)(), do: unquote(t)
    end)
  end
end
