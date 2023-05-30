defmodule StartConfig do
  require Logger

  def config() do
    %{
      server_ip: '192.168.1.129',
      server_port: 6666
    }
  end

  def get(key) do
    Map.get(config(), key)
  end

  def server_ip_port() do
    [get(:server_ip), get(:server_port)]
  end
end
