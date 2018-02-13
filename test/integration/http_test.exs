defmodule ExFlux.Integration.HTTPTest do
  use ExUnit.Case, async: false

  import Mock

  alias ExFlux.Conn.HTTP
  alias ExFlux.{LineProtocol, Point}

  @tag :integration

  setup_all do
    opts = %{
      database: "http_test",
      auth: nil,
      epoch: nil,
      host: "localhost",
      http_port: 8086,
      json_encoder: Poison
    }

    %{"results" => [%{"statement_id" => 0}]} =
      HTTP.post_query("create database http_test", opts)

    HTTP.post_query(
      "create retention policy alternate on http_test duration 1w replication 1",
      opts
    )

    on_exit(fn ->
      %{"results" => [%{"statement_id" => 0}]} =
        HTTP.post_query("drop database http_test", opts)
    end)

    {:ok, %{opts: opts}}
  end

  describe "ping/1" do
    test "with invalid opts" do
      {:error, msg} = HTTP.ping(%{host: "localhost", http_port: 1})
      assert msg == :econnrefused
    end

    test "valid opts", %{opts: opts} do
      assert opts |> Map.put(:http_opts, []) |> HTTP.ping() == :ok
    end
  end

  describe "write/2" do
    test "with invalid_opts" do
      {:error, msg} =
        HTTP.write("test value=1", %{host: "localhost", http_port: 1})

      assert msg == :econnrefused
    end

    test "bad data", %{opts: opts} do
      {:error, msg} = HTTP.write("invalid data", opts)
      assert msg =~ "invalid field format"
    end

    test "good data", %{opts: opts} do
      :ok =
        HTTP.write(
          LineProtocol.encode(%Point{
            measurement: "sample_metric",
            tags: %{},
            fields: %{value: 1}
          }),
          opts
        )
    end

    test "precision and retention policy", %{opts: opts} do
      granular =
        Map.merge(opts, %{retention_policy: "alternate", epoch: :second})

      :ok =
        HTTP.write(
          LineProtocol.encode(%Point{
            measurement: "sample_metric",
            tags: %{},
            fields: %{value: 1},
            timestamp: System.os_time(:second)
          }),
          granular
        )
    end
  end

  describe "post_query/2" do
    test "with invalid_opts" do
      {:error, msg} =
        HTTP.post_query("drop measurement some", %{
          host: "localhost",
          http_port: 1
        })

      assert msg == :econnrefused
    end
  end

  describe "query/2" do
    test "with invalid_opts" do
      {:error, msg} =
        HTTP.query("select * from some", %{host: "localhost", http_port: 1})

      assert msg == :econnrefused
    end

    test "with auth", %{opts: opts} do
      with_mock HTTPoison, get!: &mock_response/3 do
        authed =
          Map.merge(opts, %{
            host: "some",
            http_port: nil,
            secure?: true,
            auth: {"user", "pass"}
          })

        assert "select * from some"
               |> HTTP.query(authed)
               |> Map.get("uri") =~ "https://some/query"
      end
    end

    test "bad query", %{opts: opts} do
      {:error, msg} = HTTP.query("not actually a query", opts)
      assert msg =~ "error parsing query"
    end

    test "timeout", %{opts: opts} do
      http_opts = [timeout: 0]
      no_time = Map.put(opts, :http_opts, http_opts)

      {:error, :connect_timeout} =
        HTTP.query("select * from sample_metric", no_time)
    end

    test "valid query", %{opts: opts} do
      ts = System.os_time(:nanosecond)

      :ok =
        HTTP.write(
          LineProtocol.encode(%Point{
            measurement: "other_metric",
            tags: %{},
            fields: %{value: 1},
            timestamp: ts
          }),
          opts
        )

      body = HTTP.query("select value from other_metric", opts)

      assert body
             |> values()
             |> List.first()
             |> List.last() == 1

      valid_epoch = Map.put(opts, :epoch, :second)
      body = HTTP.query("select value from other_metric", valid_epoch)

      assert body
             |> values()
             |> List.last()
             |> List.first() == div(ts, 1_000_000_000)
    end
  end

  def values(response) do
    response
    |> Map.get("results")
    |> List.first()
    |> Map.get("series")
    |> List.first()
    |> Map.get("values")
  end

  def mock_response(uri, _, _) do
    %{status_code: 200, body: Poison.encode!(%{uri: uri})}
  end
end
