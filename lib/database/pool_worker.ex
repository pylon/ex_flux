defmodule ExFlux.Database.PoolWorker do
  @moduledoc """
  A single worker responsible for sending stats to the configured database
  """

  use GenServer

  require Logger

  alias ExFlux.Conn.UDP
  alias ExFlux.LineProtocol

  def child_spec(opts) do
    :poolboy.child_spec(:worker, poolboy_config(opts), Map.to_list(opts))
  end

  defp poolboy_config(opts) do
    [
      {:name, opts |> Map.fetch!(:database) |> via_tuple()},
      {:worker_module, __MODULE__},
      {:size, Map.get(opts, :pool_size)},
      {:max_overflow, Map.get(opts, :pool_overflow)}
    ]
  end

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  single pool worker initialization with deferred UDP socket setup
  """
  def init(opts) do
    Process.send(self(), {:init, opts}, [])
    {:ok, %{}}
  end

  @spec worker_pid(database :: String.t()) :: pid() | :full
  @doc """
  Perform a non-blocking checkout of an available worker for sending data. If no
  worker is available, `:poolboy.checkout/2` will return `:full`
  """
  def worker_pid(database) do
    :poolboy.checkout(
      via_tuple(database),
      false
    )
  end

  @spec send_points(pid(), points :: [map() | ExFlux.Point.t()]) :: :ok
  @doc """
  Given an identified worker via `worker_pid/1` and points, asynchronously ship
  the points to influx.
  """
  def send_points(pid, points), do: GenServer.cast(pid, {:send, points})

  @doc false
  def handle_cast({:send, points}, state) do
    send_batch(points, state)
    {:noreply, state}
  end

  defp send_batch(points, state) do
    payload =
      points
      |> Stream.map(&LineProtocol.encode/1)
      |> Enum.join("\n")

    UDP.write(
      state.udp_socket,
      state.config.host,
      state.config.udp_port,
      payload
    )
  rescue
    e ->
      Logger.debug(fn ->
        {
          Exception.format(:error, e, System.stacktrace()),
          [points: inspect(points)]
        }
      end)
  after
    # regardless of formatting errors, invalid types, etc, check the worker
    # back into the pool
    :poolboy.checkin(via_tuple(state.config.database), self())
  end

  def handle_info({:init, opts}, _state) do
    udp_opts =
      Keyword.get(
        opts,
        :udp_conn_opts
      )

    socket = UDP.open(0, udp_opts)

    config =
      opts
      |> Map.new()
      |> prepare_host()

    {:noreply, %{config: config, udp_socket: socket}}
  end

  defp prepare_host(state),
    do: Map.update(state, :host, "", &String.to_charlist/1)

  @doc false
  def via_tuple(database) do
    {:via, Registry, {ExFlux.Registry, database <> "_pool"}}
  end
end
