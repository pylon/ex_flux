defmodule ExFlux.Conn.HTTP do
  @moduledoc """
  DSL around HTTPoison for interacting with the endpoints exposed by InfluxDB
  """

  @epoch_map %{
    hour: "h",
    minute: "m",
    second: "s",
    millisecond: "ms",
    microsecond: "us",
    nanosecond: "ns",
    hours: "h",
    minutes: "m",
    seconds: "s",
    milliseconds: "ms",
    microseconds: "us",
    nanoseconds: "ns"
  }

  @doc """
  Check the status of the influxdb instance
  """
  def ping(opts) do
    headers = [] |> with_auth(opts)

    opts
    |> base_uri()
    |> endpoint("ping")
    |> HTTPoison.get!(headers, opts[:http_opts] || [])
    |> ping_response()
  rescue
    e in [HTTPoison.Error] -> {:error, e.reason}
  end

  @doc """
  Read data from influxdb

  This method is reserved for non-mutating queries (i.e. select and show). As a
  counter example, "select ... into" queries actually do mutations, so
  `post_query/2` should be used in this case
  """
  def query(query_string, opts) do
    headers = [] |> with_auth(opts)

    uri =
      opts
      |> base_uri()
      |> endpoint("query")

    params =
      query_string
      |> with_q()
      |> with_database(opts)
      |> with_epoch(opts)

    request_opts = Keyword.put(opts[:http_opts] || [], :params, params)

    uri
    |> HTTPoison.get!(headers, request_opts)
    |> query_response(opts)
  rescue
    e in [HTTPoison.Error] -> {:error, e.reason || e.message}
  end

  @doc """
  Mutate the influxdb schema

  This method with appropriate credentials is used to create
  databases, create or alter retention policies, etc.
  """
  def post_query(query_string, opts) do
    headers =
      [{"content-type", "application/x-www-form-urlencoded"}] |> with_auth(opts)

    uri =
      opts
      |> base_uri()
      |> endpoint("query")

    params =
      query_string
      |> with_q()
      |> with_database(opts)
      |> with_epoch(opts)
      |> URI.encode_query()

    http_opts = opts[:http_opts] || []

    uri
    |> HTTPoison.post!(params, headers, http_opts)
    |> query_response(opts)
  rescue
    e in [HTTPoison.Error] -> {:error, e.reason || e.message}
  end

  @doc """
  Ship datapoints to influxdb over HTTP when UDP is unreliable or unacceptable
  """
  def write(encoded_points, opts) do
    headers =
      [{"content-type", "application/x-www-form-urlencoded"}] |> with_auth(opts)

    uri =
      opts
      |> base_uri()
      |> endpoint("write")

    params =
      []
      |> with_database(opts)
      |> with_precision(opts)
      |> with_retention_policy(opts)

    request_opts = Keyword.put(opts[:http_opts] || [], :params, params)

    uri
    |> HTTPoison.post!(encoded_points, headers, request_opts)
    |> write_response(opts)
  rescue
    e in [HTTPoison.Error] -> {:error, e.reason || e.message}
  end

  # request builder functions
  defp with_auth(headers, opts) do
    # add the authorization header if needed
    case opts[:auth] do
      {username, password} ->
        [
          {"Authorization",
           "Basic " <> Base.encode64("#{username}:#{password}")}
          | headers
        ]

      _ ->
        headers
    end
  end

  defp with_q(query_string) do
    [{"q", query_string}]
  end

  defp with_database(params, %{database: db}) when is_binary(db),
    do: [{"db", db} | params]

  defp with_database(params, _opts), do: params

  defp with_precision(params, opts) do
    case Map.get(@epoch_map, opts[:epoch]) do
      p when not is_nil(p) -> [{"precision", p} | params]
      _ -> params
    end
  end

  defp with_epoch(params, opts) do
    case Map.get(@epoch_map, opts[:epoch]) do
      e when not is_nil(e) -> [{"epoch", e} | params]
      _ -> params
    end
  end

  defp with_retention_policy(params, opts) do
    case opts[:retention_policy] do
      rp when not is_nil(rp) -> [{"rp", rp} | params]
      _ -> params
    end
  end

  # uri builder fns
  defp base_uri(opts), do: "http#{secure?(opts)}://#{opts[:host]}#{port?(opts)}"

  defp secure?(%{secure?: true}), do: "s"
  defp secure?(_opts), do: ""

  defp port?(%{http_port: port}) when is_integer(port), do: ":#{port}"
  defp port?(_opts), do: ""

  defp endpoint(base, which), do: base <> "/" <> which

  # response handlers
  defp ping_response(%{status_code: 204}), do: :ok
  defp ping_response(resp), do: {:error, resp}

  defp query_response(%{status_code: 200, body: body}, opts),
    do: opts.json_encoder.decode!(body)

  defp query_response(resp, opts), do: process_error_response(resp, opts)

  defp write_response(%{status_code: 204}, _opts), do: :ok
  defp write_response(resp, opts), do: process_error_response(resp, opts)

  defp process_error_response(%{headers: head, body: body} = resp, opts) do
    if json?(head) do
      {:error, body |> opts.json_encoder.decode!() |> Map.get("error")}
    else
      {:error, resp}
    end
  end

  defp json?(headers), do: headers |> Enum.any?(&content_type_json/1)

  defp content_type_json({"Content-Type", "application/json"}), do: true
  defp content_type_json(_), do: false
end
