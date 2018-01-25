defmodule ExFlux.Database.Supervisor do
  @moduledoc """
  Orchestration and supervision of inflex database components

  The two components of an inflex database process: a "sliding buffer" queue,
  `ExFlux.Database.QueueWorker`, and a pool of connections to the influxdb
  server, `ExFlux.Database.PoolWorker`.

  The options required by the queue are:
  * `:database` - the name of the database
  * `:batch_size` - an upper limit on the number of points to send at once
  * `:max_queue_size` - a limit to the number of points to attempt to hold if
    the data cannot be shipped to influxdb fast enough
  * `:flush_interval` - a time interval in seconds used to help drain the queue

  The options required by the pool are:
  * `:database` - the name of the database
  * `:pool_size` - the number of connections/workers to maintain (via
    `:poolboy`)
  * `:pool_overflow` - if set to a number > 0, this allows poolboy to create
    extra workers when the demand for workers exceeds the supply
  * `:upd_conn_opts` - a list of one or more UDP connection options required by
    `:gen_udp`, defaults to `[:binary, {:active, false}]` since we are
    exclusively writing
  * `:host` - hostname of the influxdb server
  * `:port` - the port number influxdb is listening on for this particular
    database
  """

  use Supervisor

  alias ExFlux.Database.{PoolWorker, QueueWorker}

  @type udp_opts :: [:gen_udp.option()]
  @type option ::
          {:otp_app, atom()}
          | {:pool_size, integer()}
          | {:pool_overflow, integer()}
          | {:database, String.t()}
          | {:udp_conn_opts, udp_opts()}

  @defaults %{
    pool_size: 5,
    pool_overflow: 0,
    udp_conn_opts: [:binary, {:active, false}]
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
      PoolWorker.child_spec(opts),
      QueueWorker.child_spec(opts)
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
