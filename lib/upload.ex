defmodule Upload do
  require Logger

  def trans_info(_title, _time_cost, _timestamp) do
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
  end

  def statistics_info_update() do
    StatisticsInfo.statistics_info_update()
  end

  def recv_log(player, ts_info, msg) do
    aid = Process.get(:svr_aid, 0)

    aid > 0 &&
      Logger.info(
        "player_id: #{inspect(player.id)}, ts_info: #{inspect(ts_info)}, msg: #{inspect(msg)}"
      )
  end

  def res_log(msg) do
    aid = Process.get(:svr_aid, 0)
    aid > 0 && Logger.info("aid: #{aid} res msg is #{inspect(msg)}")
  end

  def log(msg) do
    aid = Process.get(:svr_aid, 0)

    aid > 0 &&
      Logger.info(
        "aid #{}, log msg: #{inspect(msg)}" ||
          Logger.info("log msg: #{inspect(msg)}")
      )
  end

  def log_analyse() do
    msg = SimpleStatistics.get_infos()
    # |> Enum.reduce("", fn evt_struc, t_msg ->
    #   t_msg <> "\n" <> "#{inspect evt_struc}\n"
    # end)
    Logger.info("#{inspect(msg)}")
  end

  def log_begin(msg) do
    IO.inspect(msg)
    IO.inspect("*****----->")
    Logger.info("#{inspect(msg)}")
  end
end
