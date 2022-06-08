defmodule Main do
  use Application
  import Supervisor.Spec, warn: false
  require Logger
  @mnesia_init_table Application.get_env(:pressure_test, :mnesia_init_table, [])
  @tab :wetest_api
  @tab1 :statistics_info
  @init_prev %{recv_pkg_total_num: 0, send_pkg_total_num: 0, robot_online_num: 0, robot_total_num: 0}

  def start(_type, _args) do
    all_cache_names = StartConfig.names()
    Application.put_env(:pressure_test, :names, all_cache_names)
    Application.put_env(:pressure_test, :names_length, length(all_cache_names))
    StartConfig.init_config()
    children = [
      worker(Scheduler, []),
      supervisor(Avatar.Supervisor, []),
      supervisor(WeTestApi.Supervisor, [])
    ]
    init_ets()
    LoopServer.Supervisor.start_link()
    opts = [strategy: :one_for_one, name: PressureTest.Supervisor]
    re = Supervisor.start_link(children, opts)
    # :inets.start()
    # 上报进程
    WeTestApi.init()
    (1..Application.get_env(:pressure_test, :wetest_api_num, 50))
    |> Enum.each(fn index ->
      Realm.start_wetest(index)
    end)
    StatisticsInfo.Supervisor.start_link()
    try do
      HttpService.start()
    rescue
      reason ->
      Logger.info "http start error reason : #{inspect reason}"
    end
    StartPressure.go()
    re
  end

  def init_ets() do
    SimpleStatistics.init_ets()
    :ets.new(@tab, [:set, :public, :named_table])
    :ets.new(@tab1, [:set, :public, :named_table])
    :ets.new(:lala, [:set, :public, :named_table])
    :ets.insert(@tab1, {:prev, @init_prev})
    MsgCounter.init()
  end

  def init_mnesia() do
    @mnesia_init_table |> Enum.each(fn module -> apply(module, :init_store, []) end)
  end
end
