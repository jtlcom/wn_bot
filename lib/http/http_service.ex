defmodule HttpService do
  require Logger
  @default_port 60000

  def start() do
    port = Application.get_env(:pressure_test, :cowboy_port, @default_port)

    children = [
      {Plug.Cowboy, scheme: :http, plug: PlugRouter, options: [port: port]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end

end
