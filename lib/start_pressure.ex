defmodule StartPressure do
  # import ProcessMap
  require Logger
  @wait_for_enter 5000

  def go() do
    # Process.send(Process.whereis(WeTestApi), :start_test, [])
    SimpleStatistics.update_total_num(StartConfig.chat_robot_num() + StartConfig.robot_num())
    (not WeTestApi.local_wetest?()) && Upload.register_load()
    log_file_name = "#{StartConfig.robot_machine() |> List.to_string()}.txt"
    File.exists?(log_file_name) && File.rm(log_file_name)
    start_some(StartConfig.start_id())
  end

  # @born_state 0
  # @do_nothing 8
  def start_single(id, type, line_id \\ 1) do
    # start_time = System.system_time(:millisecond)
    case Client.start(id, line_id, type) do
      {:ok, pid} ->
        # Upload.statistics_info_update(1)
        # end_time = System.system_time(:millisecond)
        # Upload.trans_info("robot id #{id} login !!!", end_time - start_time, Utils.timestamp)
        pid
      _ ->
        nil
    end
  end

  @timeout 5 * 1000
  def start_some(from_id) do 
    Guid.register(self(), :start_process)
    # 初始化场景机器人
    start_single(from_id - 1, :init_robot, -1)
    receive do
      :init_ok ->
        Upload.log_begin("init scene ok !!!!")
        Upload.log_begin("will real start")
        real_start(from_id)
      msg ->
        Upload.log_begin("erro init received #{inspect msg} !!!")
    after
      @timeout ->
        Upload.log_begin("init robot cannot init scene !!!!")
    end
  end

  def real_start(from_id) do
    Upload.log_begin("real start")
    # IO.inspect {self(), Guid.whereis(:start_process)}
    # 聊天机器人
    chat_robot = StartConfig.chat_robot_num()
    ((chat_robot > 0) && (from_id..(from_id + chat_robot - 1)) || [])
    |> Enum.each(fn id -> 
      # spawn(fn -> 
        start_single(id, :chat_robot, -1)
      # end)
      receive do
        :robot_ok ->
          :ok
        res ->
          IO.puts(:stderr, "Unexpected message received: #{inspect res}, ignore it ..... ")
      after
        @timeout ->
          IO.puts(:stderr, "start_single fail in #{@timeout} seconds")
      end
    end)
    # Mnesiam.AvatarLines.save_data(:lines, %{:chat_robots => robot_pids})
    # Process.sleep()
    strategy(StartConfig.strategy(), from_id + chat_robot)
    pid = Process.whereis(WeTestApi)
    (pid != nil) && Process.send_after(pid, :close, trunc(StartConfig.leave_after() * 60 * 1000))
  end

  def strategy('interval', from_id) do
    interval_config = StartConfig.enter_array()
    enter_num = interval_config[:enter_num] || 0
    account_time = interval_config[:account_time] || 0
    interval = interval_config[:interval] || 60
    log("use strategy is interval log in!!!!!!!!!! (every #{interval}s enter #{enter_num} player, for #{account_time} times)")

    if account_time > 0 && enter_num > 0 do
      1..account_time
      |> Enum.each(fn slice ->
        range = (from_id + (slice - 1) * enter_num)..(from_id + slice * enter_num - 1)
        range
        |> Enum.map(fn id ->
          # spawn(fn -> 
            start_single(id, :robot, slice)
          # end)
        end)
        Process.sleep(@wait_for_enter)
        Realm.broadcast(:begin, {:by_range, range})
        Process.sleep(interval * 1000)
      end)
    end
    # Process.sleep(@wait_for_enter)
  end

  def strategy('once_time', from_id) do
    Upload.log_begin("use strategy is once_time log in!!!!!!!!!!")
    log("use strategy is once_time log in!!!!!!!!!!")
    count = StartConfig.robot_num()
    (count > 0 && (from_id..(from_id + count - 1)) || [])
    |> Enum.each(fn id ->
      # spawn(fn -> 
        start_single(id, :robot, 1)
      # end)
        receive do
          :robot_ok ->
            :ok
          res ->
            Upload.log_begin("Unexpected message received: #{inspect res}, ignore it ..... ")
        after
          @timeout ->
            Upload.log_begin("start_single fail in #{@timeout} seconds")
        end
    end)
    # Process.sleep(@wait_for_enter)
    Upload.log_begin("real start avatars ok")
    msg_begin_cfg = StartConfig.msg_begin_cfg()
    Realm.broadcast_all_interval(:begin, msg_begin_cfg[:each_slice_num] || 50, msg_begin_cfg[:each_slice_delay] || 50)
    Upload.log_begin("broadcast_all_interval :begin ok !")
    pid = Process.whereis(LoopServer)
    cond do
      pid != nil ->
        Process.send_after(pid, :msg_begin_together, 10 * 1000)
        Process.send_after(pid, :start, 5 * 1000)
        StartConfig.need_move?() && Process.send_after(pid, :start_move, 30 * 1000)
      true ->
        :ok
    end
    # Process.sleep(@wait_for_enter)
  end

  def strategy('by_addition', from_id) do
    interval_config = StartConfig.enter_array()
    addition = interval_config[:addition] || 0
    account_time = interval_config[:account_time] || 0
    interval = interval_config[:interval] || 0
    Upload.log_begin("use strategy is by_addition log in!!!!!!!!!! (every #{interval}s addition #{addition} player, for #{account_time} times)")
    # log("use strategy is by_addition log in!!!!!!!!!! (every #{interval}s addition #{addition} player, for #{account_time} times)")
    if account_time > 0 && addition > 0 do
      1..account_time
      |> Enum.reduce(from_id, fn slice, new_from_id ->
        range = new_from_id..(new_from_id + slice * addition - 1)
        range
        |> Enum.map(fn id ->
          # spawn(fn -> 
            start_single(id, :robot, slice)
          # end)
        end)
        Process.sleep(@wait_for_enter)
        Realm.broadcast(:begin, {:by_range, range})
        Process.sleep(interval * 1000)
        new_from_id + slice * addition
      end)
    end
    # Process.sleep(@wait_for_enter)
  end

  def strategy(type, _id) do
    Upload.log_begin("unknown strategy type: #{inspect type}")
  end

  def log(data) do
    log_file_name = "#{StartConfig.robot_machine() |> List.to_string()}.txt"
    File.write(log_file_name, "#{inspect data}\n\n", [:append])
  end

end
