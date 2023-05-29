defmodule StatisticsInfo.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(StatisticsInfo, [StatisticsInfo], restart: :transient)
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule StatisticsInfo do
  use GenServer
  use Bitwise
  require Logger
  # alias Crontab.CronExpression.Parser
  @per_ms 200
  @tab :statistics_info
  @init_prev %{
    recv_pkg_total_num: 0,
    send_pkg_total_num: 0,
    robot_online_num: 0,
    robot_total_num: 0
  }

  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def init(:ok) do
    Process.send(self(), :enter_loop, [])
    {:ok, %{}}
  end

  def handle_info(:enter_loop, state) do
    StatisticsInfo.statistics_info_update()
    Process.send_after(self(), :enter_loop, @per_ms)
    {:noreply, state}
  end

  def handle_info(:stop, state) do
    Logger.info("stop statistics_info server !!!")
    {:stop, :normal, state}
  end

  def handle_info(what, state) do
    Logger.info("statistics_info recv what msg is : #{inspect(what)} !!!")
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.info("statistics_info server terminate, reason : #{inspect(reason)} !!!")
  end

  def statistics_info_update(_num \\ 0) do
    prev = Keyword.get(:ets.lookup(@tab, :prev), :prev) || @init_prev
    # IO.inspect "prev #{inspect prev}"
    # Logger.info "robot_online_num : #{robot_online_num}"
    new_prev =
      Enum.zip(
        [:recv_pkg_total_num, :send_pkg_total_num, :robot_total_num, :robot_online_num],
        MsgCounter.take_counts()
      )
      |> Map.new()

    # IO.inspect "new_prev #{inspect new_prev}"
    # Logger.info "#{inspect new_prev}"
    data =
      Enum.map(prev, fn {k, v} ->
        {k, (new_prev[k] || 0) - v}
      end)
      |> Map.new()

    transParamsStr = %{data: data}

    # IO.inspect "#{inspect {transParamsStr[:data][:robot_total_num], transParamsStr[:data][:robot_online_num]}}"
    :ets.insert(@tab, {:prev, new_prev})

    if data[:robot_online_num] <= data[:robot_total_num] do
      SimpleStatistics.update_onlies(data[:robot_online_num] || 0)
      # GenServer.cast(WeTestApis, {:statistics_info, transParamsStr})
    end
  end
end
