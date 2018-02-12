defmodule ExFlux.Conn.UDPTest do
  use ExUnit.Case

  alias ExFlux.Conn.UDP

  test "socket lifecycle" do
    socket = UDP.open(0)
    assert UDP.close(socket) == :ok

    assert :gen_udp.send(socket, 'localhost', 8086, 'test value=1') ==
             {:error, :closed}
  end
end
