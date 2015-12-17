defmodule Croma.Util do
  @moduledoc """
  Utilities to manipulate type expressions.
  """

  def list_to_type_union([v    ]), do: v
  def list_to_type_union([h | t]), do: {:|, [], [h, list_to_type_union(t)]}
end
