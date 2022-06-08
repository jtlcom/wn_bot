defmodule ServerConfig do
  # @config_file Application.get_env(:pressure_test, :serverlist_file, "./config/serverlist.txt")
  # @server_name Application.get_env(:pressure_test, :server_name, "long")
  # @ip Application.get_env(:pressure_test, :ip, '127.0.0.1')
  # @port Application.get_env(:pressure_test, :port, 2256)
  
  def server_ip_port(:by_file) do
    {:ok, lala} = File.read(Application.get_env(:pressure_test, :serverlist_file, "./config/serverlist.txt"))
    server_info = lala |> String.split(~r{[^0-9A-Za-z.]})
    |> Enum.reject(&(&1 == ""))
    |> Enum.chunk_every(9)
    |> Enum.find(fn [na | _] -> na == Application.get_env(:pressure_test, :server_name, "long") end)
    (server_info == nil) && ['', 0] || [Enum.at(server_info, 3) |> String.to_charlist, Enum.at(server_info, 4) |> String.to_integer]
  end

  def server_ip_port() do
    StartConfig.server_ip_port()
  end

end