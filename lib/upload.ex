defmodule Upload do
  require Logger

  def trans_info(title, time_cost, timestamp) do
    # transParamsStr = 
      # %{data: 
      #  [
        # %{
        #   trans_name: title, 
        #   time_cost: time_cost, 
        #   trans_result: 1,
        #   timestamps: timestamp
        # }
      #  ]
    # } 
    aid = Process.get(:avatar_id, 0)
    if (Process.get(:robot_type) != :init_robot) do
      pid = Guid.whereis(Guid.new(:wetest, Integer.mod(aid, Application.get_env(:pressure_test, :wetest_api_num, 50)) + 1))# |> IO.inspect
      (is_pid(pid) && (time_cost < 10000)) && GenServer.cast(pid, {:trans_info, {title, time_cost, timestamp}})
    end
  end

  def register_load() do
    WeTestApi.register_load()
  end

  def stop() do
    WeTestApi.stop_test()
  end

  def statistics_info_update() do
    StatisticsInfo.statistics_info_update()
  end

  def recv_log(player, ts_info, msg) do
    aid = Process.get(:svr_aid, 0)
    (if_log?(msg) && aid > 0) 
      && Logger.info "player_id: #{inspect player.id}, c_id: #{inspect player.c_id}, ts_info: #{inspect ts_info}, msg: #{inspect msg}"
  end

  def res_log(msg) do
    aid = Process.get(:svr_aid, 0)
    (if_log?(msg) && aid > 0) 
      && Logger.info "aid: #{aid} res msg is #{inspect msg}"
  end

  def log(msg) do
    aid = Process.get(:svr_aid, 0)
    (aid > 0 )
      && Logger.info "aid #{}, log msg: #{inspect msg}"
      || Logger.info "log msg: #{inspect msg}"
  end

  def log_analyse() do
    msg = SimpleStatistics.get_infos()
    # |> Enum.reduce("", fn evt_struc, t_msg ->
    #   t_msg <> "\n" <> "#{inspect evt_struc}\n"
    # end)
    Logger.info "#{inspect msg}"
  end

  def log_begin(msg) do
    IO.inspect(msg)
    IO.inspect("*****----->")
    Logger.info "#{inspect msg}"
  end

  def if_log?(msg) do
    case StartConfig.log_to_file() && msg do
      [msg_head | _] ->
        msg_head not in StartConfig.not_log_heads()
      res when is_boolean(res) ->
        res
      _ ->
        true
    end
  end

end