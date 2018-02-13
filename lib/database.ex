defmodule ExFlux.Database do
  @moduledoc """
  Configuration of a single database's connection pool, queue and supervision
  tree. Since InfluxDB uses a single server UDP port per database, this
  library's goal is to make it easy to do 1:1 mappings of a pool of UDP
  connections to that destination's port and batching datapoints.

  To get started, create your own module and do something like:

      use ExFlux.Database, otp_app: :your_app, database: "your_db_name"

  In your application, simply add `YourApp.YourExFluxDatabase` to the children:

      children = [
        ...,
        YourApp.YourExFluxDatabase
      ]

  The database name isn't used for the UDP connection in anyway, but it is used
  to create database-specific workers. To support querying interfaces and HTTP
  based sending, the database would need to be known. To support these features
  in the future, the database name is held by all workers in their
  configuration.

  Where possible, `ExFlux.Database.Supervisor` provides sane defaults for
  configuration options to make it as close as working out of the box as
  possible. A full list of configuration options and their types can be found
  there.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @otp_app Keyword.fetch!(opts, :otp_app)
      @database Keyword.get(opts, :database)

      alias ExFlux.Database.{HTTPWorker, QueueWorker}
      alias ExFlux.Database.Supervisor, as: DBSupervisor

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(opts \\ []) do
        opts = Keyword.put_new(opts, :database, @database)
        DBSupervisor.start_link(__MODULE__, @otp_app, opts)
      end

      def post(query_string) do
        HTTPWorker.post(@database |> database_name(), query_string)
      end

      def push(%{} = point) do
        GenServer.cast(
          @database |> database_name() |> QueueWorker.via_tuple(),
          {:push, point}
        )
      end

      def query(query_string) do
        HTTPWorker.query(@database |> database_name(), query_string)
      end

      @spec database_name(prov :: String.t() | nil) :: String.t()
      defp database_name(prov) do
        @otp_app
        |> Application.get_env(__MODULE__, [])
        |> Keyword.get(:database, prov)
      end

      defoverridable child_spec: 1
    end
  end

  @doc """
  POST to the /query for the configured database. This is used for queries that
  mutate the database. See `ExFlux.Conn.HTTP.post_query/2` for more details
  """
  @callback post(query_string :: String.t()) :: map() | {:error, any()}

  @doc """
  queue a single data point (may trigger a batch being sent asynchronously)
  """
  @callback push(point :: ExFlux.Point.t() | map()) :: :ok

  @doc """
  using the dataabase's http configuration, query the influx database
  """
  @callback query(query_string :: String.t()) :: map() | {:error, any()}
end
