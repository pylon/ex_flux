defmodule ExFlux.Integration.DatabaseTest do
  use ExUnit.Case, async: false

  alias ExFlux.TestDatabase
  alias ExFlux.Database.{PoolWorker, QueueWorker}

  setup_all do
    TestDatabase.start_link([])

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
      |> GenServer.call(:peek)

    assert state.size == 0
  end

  test "push and batch" do
    10..19
    |> Stream.map(&create_point/1)
    |> Enum.each(&TestDatabase.push/1)

    state =
      "test"
      |> QueueWorker.via_tuple()
      |> GenServer.call(:peek)

    assert state.size == 0
  end

  test "bad data" do
    10..14
    |> Stream.map(&create_point/1)
    |> Stream.map(&Map.put(&1, :fields, %{}))
    |> Enum.each(&TestDatabase.push/1)

    state = "test" |> QueueWorker.via_tuple() |> GenServer.call(:peek)

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
      timestamp: System.os_time(:nanosecond)
    }
  end
end
