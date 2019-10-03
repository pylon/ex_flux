defmodule ExFlux.Point do
  @moduledoc """
  Data points as Elixir structs

  For simplicity, timestamps are only dealt with in the unix format within the
  library. Additionally, both in the typespecs and in the `ExFlux.LineProtocol`
  implementation, strings and atoms can be used interchangably in places where
  the influx line protocol specification calls for strings.
  """

  @type influx_string :: String.t() | atom()

  @type timestamp :: integer()

  @type field_value :: influx_string() | boolean() | number()

  @type field_map :: %{influx_string() => field_value()}

  @type tag_value :: influx_string()

  @type tag_map :: %{optional(influx_string()) => tag_value()}

  @type t :: %__MODULE__{
          measurement: String.t(),
          fields: field_map(),
          tags: tag_map(),
          timestamp: timestamp()
        }

  @enforce_keys [:measurement, :fields]
  defstruct [:measurement, :timestamp, fields: %{}, tags: %{}]
end
