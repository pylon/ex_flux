defmodule Inflex.FieldError do
  @moduledoc """
  Raised when no fields were specified on the provided data point
  """

  defexception message: "measurements must have one or more fields"
end
