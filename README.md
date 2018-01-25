# ExFlux

An [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb/)
driver that is designed from the ground up to bend, not break under load. In order to accomplish this there were three major design goals:

1. Effectively utilize the [InfluxDB UDP
   protocol](https://github.com/influxdata/influxdb/blob/master/services/udp/README.md)
   by making batched writes a part of the library.
2. Support the complete [Influx line
   protocol](https://docs.influxdata.com/influxdb/v1.4/write_protocols/line_protocol_reference/)
   with proper escaping and type support
3. Handle load accountably and shed load in a defined [FIFO](https://en.wikipedia.org/wiki/FIFO_(computing_and_electronics)) manner when stats cannot be shipped
   fast enough:
   -  prioritize casts over calls 
   -  [drop datapoints from the queue, oldest first](https://clojuredocs.org/clojure.core.async/sliding-buffer), when the queue is full and all UDP socket workers are busy.
   

## Documentation

Full documentation can be found on [hexdocs](https://hexdocs.pm/ex_flux)


## Installation

Now [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_flux` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_flux, "~> 0.1.0"}
  ]
end
```

## Example

As explained in the [Influx UDP protocol](https://github.com/influxdata/influxdb/blob/master/services/udp/README.md), InfluxDB specifies that a UDP port maps to
exactly one configured database. Example configuration for InfluxDB .conf files
can be found at the bottom of the [Influx udp protocol
page](https://github.com/influxdata/influxdb/blob/master/services/udp/README.md#config-examples)

Create an `ExFlux.Database` in your project:
```elixir
defmodule YourApp.SpecificDatabase do
   use ExFlux.Database, otp_app: :your_app, database: "database_name"
end
```

Add it to your `application.ex`:
```elixir
      children = [
        ...,
        YourApp.YourInfluxDatabase
      ]
```

To add points in a series, use `ExFlux.Points` or regular elixir maps interchangeably. A helper for defining series schema is a [Near Term TODO](https://github.com/pylon/ex_flux#near-term-todos).

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
