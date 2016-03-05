defmodule Croma.BuiltinTypeTest do
  use ExUnit.Case

  test "validate/1" do
    [
      {Croma.Atom         , :a           , 0       },
      {Croma.Boolean      , true         , 0       },
      {Croma.Float        , 0.0          , 0       },
      {Croma.Integer      , 0            , 0.0     },
      {Croma.Number       , 0            , nil     },
      {Croma.String       , "a"          , 'a'     },
      {Croma.Binary       , <<1::8>>     , <<1::4>>},
      {Croma.BitString    , <<1::1>>     , nil     },
      {Croma.Function     , fn -> 1 end  , 0       },
      {Croma.Pid          , self         , 0       },
      {Croma.Port         , hd(Port.list), 0       },
      {Croma.Reference    , make_ref     , 1       },
      {Croma.Tuple        , {}           , []      },
      {Croma.List         , []           , %{}     },
      {Croma.Map          , %{}          , []      },
      {Croma.Byte         , 255          , 256     },
      {Croma.Char         , 0x10ffff     , 0x110000},
      {Croma.PosInteger   , 1            , 0       },
      {Croma.NegInteger   , -1           , 0       },
      {Croma.NonNegInteger, 0            , -1      },
    ]
    |> Enum.each(fn {mod, o, e} ->
      assert mod.validate(o) == {:ok, o}
      assert mod.validate(e) == {:error, {:invalid_value, [mod]}}
    end)
  end
end
