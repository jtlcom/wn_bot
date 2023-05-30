defmodule HttpService do
  require Logger

  def start() do
    port = Application.get_env(:whynot_bot, :http_port)

    children = [
      {Plug.Cowboy, scheme: :http, plug: PlugRouter, options: [port: port]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
