defmodule ExFlux.Database.QueueWorker do
  @moduledoc """
  Async queueing of `ExFlux.Point`s and load shedding per database

  Batching must be done per-database. To support this effectively, a single
  worker for each database receives datapoints from your service. If the queue
  is sufficiently full, it will command one of its pool workers to send a
  portion of your stats using the configured connection (UDP or HTTP).

  The queue is implemented via Erlang's `:queue` and the size is tracked
  alongside the queue to reduce the frequency of calculating the length.
  """

  use GenServer

  alias ExFlux.Database.PoolWorker

  @doc false
  def start_link(opts) do
    GenServer.start_link(
      __MODULE__,
      opts,
      name: via_tuple(opts.database)
    )
  end

  @doc """
  Schedule a the initial flush of queued data points, create the `:queue`, and
  initialize the size which is tracked manually to avoid calculating the length
  of the queue via `:queue.len/1`
  """
  @spec init(config :: map()) ::
          {:ok,
           %{queue: :queue.queue(), config: map(), size: non_neg_integer()}}
  def init(config) do
    schedule_flush(config.flush_interval)
    {:ok, %{queue: :queue.new(), config: config, size: 0}}
  end

  @doc false
  def handle_cast({:push, point}, %{queue: old, size: size} = state) do
    new_size = size + 1
    new_queue = :queue.in(point, old)

    {final_queue, final_size} =
      case new_size >= state.config.batch_size and
             PoolWorker.worker_pid(state.config.database) do
        worker when is_pid(worker) ->
          {out, queue} = :queue.split(state.config.batch_size, new_queue)

          PoolWorker.send_points(worker, :queue.to_list(out))
          {queue, new_size - state.config.batch_size}

        _ ->
          sliding_queue(new_queue, state.config.max_queue_size, new_size)
      end

    {:noreply, %{state | queue: final_queue, size: final_size}}
  end

  @doc false
  def handle_info(:flush, %{size: 0} = state) do
    schedule_flush(state.config.flush_interval)
    {:noreply, state}
  end

  @doc false
  def handle_info(:flush, %{queue: queue, size: size} = state) do
    schedule_flush(state.config.flush_interval)

    worker = PoolWorker.worker_pid(state.config.database)

    if is_pid(worker) do
      batch_size = min(size, state.config.batch_size)
      {out, rest} = :queue.split(batch_size, queue)

      PoolWorker.send_points(worker, :queue.to_list(out))

      {:noreply, %{state | queue: rest, size: size - batch_size}}
    else
      {:noreply, state}
    end
  end

  defp sliding_queue(queue, max_size, curr_size) when curr_size > max_size do
    {:queue.drop(queue), max_size}
  end

  defp sliding_queue(queue, _max_size, curr_size), do: {queue, curr_size}

  defp schedule_flush(interval_in_sec) do
    Process.send_after(self(), :flush, interval_in_sec * 1000)
  end

  @doc false
  def via_tuple(database),
    do: {:via, Registry, {ExFlux.Registry, database <> "_queue"}}
end
