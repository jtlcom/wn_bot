defmodule HttpService do
  require Logger

  def start() do
    port = Application.get_env(:pressure_test, :http_port)

    children = [
      {Plug.Cowboy, scheme: :http, plug: PlugRouter, options: [port: port]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
