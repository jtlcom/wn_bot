defmodule Main do
  use Application
  import Supervisor.Spec, warn: false
  require Logger
  @tab1 :statistics_info
  @init_prev %{
    recv_pkg_total_num: 0,
    send_pkg_total_num: 0,
    robot_online_num: 0,
    robot_total_num: 0
  }

  def start(_type, _args) do
    children = [
      worker(Scheduler, []),
      supervisor(Avatar.Supervisor, [])
    ]

    HttpService.start()
    init_ets()
    LoopServer.Supervisor.start_link()
    opts = [strategy: :one_for_one, name: PressureTest.Supervisor]
    re = Supervisor.start_link(children, opts)
    StatisticsInfo.Supervisor.start_link()
    :observer.start()
    # StartPressure.go()
    re
  end

  def init_ets() do
    SimpleStatistics.init_ets()
    Avatar.Ets.start()
    Http.Ets.start()
    :ets.new(@tab1, [:set, :public, :named_table])
    :ets.insert(@tab1, {:prev, @init_prev})
    MsgCounter.init()
  end
end
