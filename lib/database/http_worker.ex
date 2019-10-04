defmodule ExFlux.Database.HTTPWorker do
  @moduledoc """
  Provides a wrapper around the `:hackney` pool used for querying/writing on
  behalf of a paritcular database.
  """

  use GenServer

  alias ExFlux.Conn.HTTP
  alias ExFlux.{LineProtocol, Point}

  @doc false
  def start_link(opts) do
    GenServer.start_link(
      __MODULE__,
      opts,
      name: via_tuple(opts.database)
    )
  end

  def init(opts) do
    name = table_name(opts.database)
    :ets.new(name, [:set, :protected, :named_table])
    :ets.insert(name, [{:opts, with_hackney_pool(opts)}])
    {:ok, nil}
  end

  @doc """
  Use the database specific info to ping the target influx server
  """
  @spec ping(database :: String.t()) :: :ok | {:error, reason :: any()}
  def ping(database) do
    opts =
      database
      |> table_name()
      |> opts_lookup()

    HTTP.ping(opts)
  end

  @doc """
  Using the database specific configuration, execute the query
  """
  @spec query(database :: String.t(), query_string :: String.t()) ::
          map() | {:error, any()}
  def query(database, query_string) do
    opts =
      database
      |> table_name()
      |> opts_lookup()

    HTTP.query(query_string, opts)
  end

  @doc """
  Use the `:post` HTTP request method to send the query string to the provided
  database.
  """
  @spec post(database :: String.t(), query_string :: String.t()) ::
          map() | {:error, any()}
  def post(database, query_string) do
    opts =
      database
      |> table_name()
      |> opts_lookup()

    HTTP.post_query(query_string, opts)
  end

  @doc """
  Use HTTP request/response semantics to ship metrics to the specific influx
  database. This is especially useful when UDP is not a viable option.
  """
  @spec write(database :: String.t(), points :: [Point.t() | map()]) ::
          :ok | {:error, any()}
  def write(database, points) do
    opts =
      database
      |> table_name()
      |> opts_lookup()

    HTTP.write(
      points
      |> Stream.map(&LineProtocol.encode/1)
      |> Enum.join("\n"),
      opts
    )
  end

  defp opts_lookup(table_name) do
    case :ets.lookup(table_name, :opts) do
      [{:opts, opts}] -> opts
    end
  end

  @doc false
  def pool_name(%{database: db}) do
    String.to_atom(db <> "_hackney_pool")
  end

  defp table_name(db), do: String.to_atom(db <> "_http_config")

  defp with_hackney_pool(opts) do
    %{
      opts
      | http_opts: Keyword.put(opts.http_opts, :hackney, pool: pool_name(opts))
    }
  end

  @doc false
  def via_tuple(database) do
    {:via, Registry, {ExFlux.Registry, database <> "_http"}}
  end
end
