defmodule StartConfig do
  require Logger

  def config() do
    %{
      server_ip: '127.0.0.1',
      server_port: 6666,
      strategy: :once_time
    }
  end

  def get(key) do
    Map.get(config(), key)
  end

  def server_ip_port() do
    [get(:server_ip), get(:server_port)]
  end
end
