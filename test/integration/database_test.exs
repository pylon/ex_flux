defmodule ExFlux.Integration.DatabaseTest do
  use ExUnit.Case, async: false

  alias ExFlux.Conn.HTTP
  alias ExFlux.TestDatabase
  alias ExFlux.Database.{PoolWorker, QueueWorker, HTTPWorker}

  setup_all do
    TestDatabase.start_link([])

    TestDatabase.post("create database test")

    on_exit(fn ->
      opts = %{
        host: "localhost",
        http_port: 8086,
        database: "test",
        json_encoder: Poison
      }

      HTTP.post_query("drop database test", opts)
    end)

    :ok
  end

  @tag :integration
  test "push and flush" do
    0..3
    |> Stream.map(&create_point/1)
    |> Enum.each(&TestDatabase.push/1)

    :timer.sleep(1_500)

    state =
      "test"
      |> QueueWorker.via_tuple()
      |> GenServer.whereis()
      |> :sys.get_state()

    assert state.size == 0
  end

  @tag :integration
  test "push and batch" do
    10..19
    |> Stream.map(&create_point/1)
    |> Enum.each(&TestDatabase.push/1)

    state =
      "test"
      |> QueueWorker.via_tuple()
      |> GenServer.whereis()
      |> :sys.get_state()

    assert state.size == 0
  end

  @tag :integration
  test "bad data" do
    10..14
    |> Stream.map(&create_point/1)
    |> Stream.map(&Map.put(&1, :fields, %{}))
    |> Enum.each(&TestDatabase.push/1)

    state =
      "test"
      |> QueueWorker.via_tuple()
      |> GenServer.whereis()
      |> :sys.get_state()

    assert state.size == 0

    :timer.sleep(1_000)

    workers =
      0..4
      |> Enum.map(fn _ -> PoolWorker.worker_pid("test") end)

    assert Enum.all?(workers, &is_pid/1), inspect(workers)

    workers
    |> Enum.each(fn p ->
      "test" |> PoolWorker.via_tuple() |> :poolboy.checkin(p)
    end)
  end

  @tag :integration
  test "HTTPWorker tests" do
    HTTPWorker.write(
      "test",
      10..50
      |> Stream.map(&create_point/1)
      |> Enum.map(&Map.put(&1, :measurement, "metric"))
    )

    %{"results" => post_res} =
      TestDatabase.post(
        "create retention policy alternate on test duration 1w replication 1"
      )

    refute Enum.empty?(post_res)

    %{"results" => res} = TestDatabase.query("select sum(input) from metric")

    assert res
           |> List.first()
           |> Map.get("series")
           |> List.first()
           |> Map.get("values")
           |> List.first()
           |> List.last() == Enum.sum(10..50)
  end

  def create_point(input) do
    %{
      measurement: "measure",
      fields: %{
        input: input,
        value: :rand.uniform(10)
      },
      tags: %{
        tag0:
          if :rand.uniform() > 0.5 do
            "val0"
          else
            "val1"
          end
      },
      timestamp: System.os_time(:microsecond)
    }
  end
end
