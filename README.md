# Inflex

An [InfluxDB driver](https://www.influxdata.com/time-series-platform/influxdb/)
driver that is designed from the ground up to bend, not break under load. In
order to accomplish this, there were three major design goals:

1. Effectively utilize the [InfluxDB UDP
   protocol](https://github.com/influxdata/influxdb/blob/master/services/udp/README.md)
   by making batched writes a part of the library.
2. Support the complete [line
   protocol](https://docs.influxdata.com/influxdb/v1.4/write_protocols/line_protocol_reference/)
   with proper escaping and type support
3. Account and plan for how to handle/shed load when stats cannot be shipped
   fast enough. This is done by prioritizing casts over calls as well as
   allowing the queue to drop datapoints, oldest first, when the queue is full
   and all UDP socket workers are busy.
   

## Documentation

Full documentation can be found on [hexdocs](https://hexdocs.pm/inflex)


## Installation

Now [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `inflex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:inflex, "~> 0.1.0"}
  ]
end
```

## Example

As explained in the UDP protocol, InfluxDB specifies that a UDP port maps to
exactly one configured database. Example configuration for InfluxDB .conf files
can be found at the bottom of the [udp protocol
page](https://github.com/influxdata/influxdb/blob/master/services/udp/README.md)

Create an `Inflex.Database` in your project:
```elixir
defmodule YourApp.SpecificDatabase do
   use Inflex.Database, otp_app: :your_app, database: "database_name"
end
```

Add it to your application:
```elixir
      children = [
        ...,
        YourApp.YourInflexDatabase
      ]
```

Currently, there isn't a helper for defining series schema, but you can just use
`Inflex.Point`s or regular elixir maps interchangably for now:

```elixir
iex(1)> point = %{measurement: "series_name", fields: %{value: 1}, tags: %{}, timestamp: System.os_time(:nanosecond)}
iex(2)> YourApp.SpecificDatabase.push(point)
```

The point will be queued asynchronously and either flushed or sent as part of a batch.


## Near Term TODOs

* series specification
* timestamp granularity support
* query interface
* test for load shedding


## License

Copyright 2018 Pylon, Inc.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
