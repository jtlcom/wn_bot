defmodule Main do
  use Application
  import Supervisor.Spec, warn: false
  require Logger

  def start(_type, _args) do
    children = [
      {PartitionSupervisor, child_spec: DynamicSupervisor, name: Avatar.DynamicSupervisors},
      %{id: HttpMgr, start: {HttpMgr, :start_link, [HttpMgr]}}
    ]

    HttpService.start()
    init_ets()
    opts = [strategy: :one_for_one, name: WhynotBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def init_ets() do
    SimpleStatistics.init_ets()
    Avatar.Ets.start()
    Http.Ets.start()
    Count.Ets.start()
    MsgCounter.init()
  end
end
