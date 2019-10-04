defmodule ExFlux.Conn.UDP do
  @moduledoc """
  Light, opinionated wrapper around `:gen_udp`
  """

  @doc """
  Open a port for UDP with all of the configuration afforded to you by
  `:gen_udp.open/2`
  """
  @spec open(
          port :: :inet.port_number() | integer(),
          udp_opts :: [:gen_udp.option()]
        ) :: :gen_udp.socket()
  def open(port \\ 0, udp_opts \\ [:binary, {:active, false}]) do
    {:ok, socket} = :gen_udp.open(port, udp_opts)
    socket
  end

  @doc """
  Where possible, sockets should be closed as a well-behaved program
  """
  @spec close(socket :: :gen_udp.socket()) :: :ok
  def close(socket) do
    :gen_udp.close(socket)
  end

  @doc """
  Convert the string to utf-8 binary and send via udp
  """
  @spec write(
          socket :: :gen_udp.socket(),
          host :: :inet.ip_address(),
          port :: :inet.port_number() | integer(),
          String.t()
        ) :: :ok | {:error, reason :: any()}
  def write(socket, host, port, payload) do
    :gen_udp.send(
      socket,
      host,
      port,
      :unicode.characters_to_binary(payload)
    )
  end
end
