defmodule Main do
  use Application
  import Supervisor.Spec, warn: false
  require Logger

  def start(_type, _args) do
    children = [
      supervisor(Avatar.Supervisor, [])
    ]

    HttpService.start()
    init_ets()
    opts = [strategy: :one_for_one, name: WhynotBot.Supervisor]
    re = Supervisor.start_link(children, opts)
    :observer.start()
    # StartPressure.go('192.168.1.129', 6666, "bot_1_", 1, 2, 1)
    re
  end

  def init_ets() do
    SimpleStatistics.init_ets()
    Avatar.Ets.start()
    Http.Ets.start()
    Count.Ets.start()
    MsgCounter.init()
  end
end
