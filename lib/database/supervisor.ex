defmodule ExFlux.Database.Supervisor do
  @moduledoc """
  Orchestration and supervision of ex_influx database components

  The two components of an ex_influx database process: a "sliding buffer" queue,
  `ExFlux.Database.QueueWorker`, and a pool of connections to the influxdb
  server, `ExFlux.Database.PoolWorker`.

  Common options for the queue, pool and/or the query interface:
  * `:database` - the name of the database
  * `:host` - hostname of the influxdb server

  The options required by the queue are:
  * `:batch_size` - an upper limit on the number of points to send at once
  * `:max_queue_size` - a limit to the number of points to attempt to hold if
    the data cannot be shipped to influxdb fast enough
  * `:flush_interval` - a time interval in seconds used to help drain the queue

  The options required by the pool are:
  * `:pool_size` - the number of connections/workers to maintain (via
    `:poolboy`)
  * `:pool_overflow` - if set to a number > 0, this allows poolboy to create
    extra workers when the demand for workers exceeds the supply
  * `:upd_conn_opts` - a list of one or more UDP connection options required by
    `:gen_udp`, defaults to `[:binary, {:active, false}]` since we are
    exclusively writing
  * `:udp_port` - the port number influxdb is listening on for this particular
    database

  The options required by the http interface:
  * `:http_port` - the port number for the query interface (defaults to 8086)
  * `:json_encoder` - encoder/decoder to use for responses, defaults to `Poison`
  * `:http_opts` - extra options passed to `HTTPoison` see `HTTPoison.request/5`
    for more details (defaults to `[timeout: 5000]`)
  """

  use Supervisor

  alias ExFlux.Database.{HTTPWorker, PoolWorker, QueueWorker}

  @udp_opts [:binary, {:active, false}]
  @http_opts [timeout: 5000]
  @defaults %{
    host: "localhost",
    batch_size: 10,
    max_queue_size: 100,
    flush_interval: 10,
    udp_port: 8089,
    pool_size: 5,
    pool_overflow: 0,
    udp_conn_opts: @udp_opts,
    json_encoder: Poison,
    http_port: 8086,
    http_opts: @http_opts
  }

  def start_link(mod, otp_app, opts) do
    final_opts =
      mod
      |> process_env(otp_app)
      |> Map.put_new(:database, Keyword.get(opts, :database))

    Supervisor.start_link(
      __MODULE__,
      final_opts,
      name: final_opts |> Map.fetch!(:database) |> via_tuple()
    )
  end

  def init(opts) do
    children = [
      :hackney_pool.child_spec(HTTPWorker.pool_name(opts), []),
      PoolWorker.child_spec(opts),
      QueueWorker.child_spec(opts),
      HTTPWorker.child_spec(opts)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @spec process_env(atom(), atom()) :: map()
  @doc """
  Merge the config and defaults to create a single cohesive configuration map to
  be used by the pool worker, poolboy, and the queue worker.
  """
  def process_env(mod, otp_app) do
    config_opts =
      otp_app
      |> Application.get_env(mod, [])
      |> Map.new()

    Map.merge(@defaults, config_opts)
  end

  def via_tuple(database) do
    {:via, Registry, {ExFlux.Registry, database <> "_supervisor"}}
  end
end
