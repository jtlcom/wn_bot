defmodule ServerConfig do
  # @config_file Application.get_env(:pressure_test, :serverlist_file, "./config/serverlist.txt")
  # @server_name Application.get_env(:pressure_test, :server_name, "long")
  # @ip Application.get_env(:pressure_test, :ip, '127.0.0.1')
  # @port Application.get_env(:pressure_test, :port, 2256)

  def server_ip_port() do
    StartConfig.server_ip_port()
  end

end
