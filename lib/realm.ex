defmodule Realm do
  require Logger

  def start_avatar(id, line_id, type) do
    Avatar.Supervisor.start_child {id, line_id, type}, [name: {:global, {:name, Guid.name(id)}}]
  end

  def start_wetest(id) do
    WeTestApi.Supervisor.start_child {:child, id}, [name: {:global, {:name, Guid.new(:wetest, id)}}]
  end

  # def start_chat(id, a_pid, a_conn, type) do
  #   Chat.Supervisor.start_child {id, a_pid,a_conn, type}, [name: {:global, {:name, Guid.new(:chat, id)}}]
  # end

  def start_statistics() do
    StatisticsInfo.Supervisor.start_link()
  end

  def control(avatar, request) do
    GenServer.cast(avatar, request)
  end

  def broadcast_each_delay(msg, delay \\ 0) do
    Supervisor.which_children(Avatars)
    |> Enum.each(fn {_, pid, _, _} ->
      # spawn(fn -> 
        GenServer.cast(pid, msg)
        (delay > 0) && Process.sleep(delay)
      # end)
    end)
  end

  def broadcast(msg) do
    Supervisor.which_children(Avatars)
    |> Enum.each(fn {_, pid, _, _} ->
      # spawn(fn -> 
        GenServer.cast(pid, msg)
        # Process.sleep(1000)
      # end)
    end)
  end

  def broadcast(msg, strategy) do
    get_lines_avatars(strategy)
    |> Enum.each(fn pid ->
      spawn(fn -> 
        GenServer.cast(pid, msg)
      end)
    end)
  end

  def broadcast_all_interval(msg, slice \\ 50, interval \\ 1000) do    # 所有avatar按照slice数量分组，每组执行间隔interval毫秒
    slices = get_lines_avatars({:by_slice, slice})
    is_begin? = (msg == :begin)
    is_begin? && Upload.log_begin("broadcast all begin, slice num: #{inspect length(slices)}")#,\n slices: #{inspect slices, pretty: true}
    slices
    |> Enum.with_index(1)
    |> Enum.each(fn {slice, slice_index} ->
      Enum.each(slice, fn pid ->
        spawn(fn -> 
          GenServer.cast(pid, msg)
        end)
      end)
      Process.sleep(interval)
      is_begin? && Upload.log_begin("slice broadcast begin over, slice index: #{slice_index}, slice_len: #{inspect length(slice)}, slice: #{inspect slice, pretty: true}")
    end)
  end
 
  def broadcast_avatars_handle(msg, strategy) do
    get_lines_avatars(strategy)
    |> Enum.each(fn pid -> 
      Process.sleep(1)
      GenServer.cast(pid, msg)
    end)
  end

  def broadcast_avatars_handle_after(msg, strategy, delay \\ 200) do
    get_lines_avatars(strategy)
    |> Enum.each(fn pid -> 
      Process.sleep(delay)
      GenServer.cast(pid, msg)
    end)
  end

  # type %{by_line: lines} %{by_num: num}
  def broadcast_avatars(msg, strategy) do
    get_lines_avatars(strategy)
    |> Enum.with_index()
    |> Enum.each(fn {pid, index} -> 
      IO.inspect {pid, index}
      Process.sleep(10)
      GenServer.cast(pid, {:reply, msg}) 
    end)
  end

  def broadcast_chat_robot(msg) do
    get_lines_avatars(:chat)
    |> Enum.each(fn pid -> 
      GenServer.cast(pid, msg) 
    end)
  end

  def broadcast_avatars_delay(msg, strategy, intervl \\ 5) do
    get_lines_avatars(strategy)
    |> Enum.reduce(0, fn pid, num -> 
      GenServer.cast(pid, {:reply, msg, num * intervl}) 
      num + 1
    end)
  end

  def sendto_server_by_one_of_avatars(msg) do
    avatars = Supervisor.which_children(Avatars) 
    if avatars != [] do
      {_, pid, _, _} = avatars |> Enum.random
      GenServer.cast(pid, {:reply, msg})
    end
  end

  def get_lines_avatars({:by_num, num}) do
    from_id = StartConfig.start_id()
    from_id..(from_id + num)
    |> Enum.map(fn id ->
      Guid.whereis(id)
    end)
    |> Enum.filter(&(is_pid(&1)))
  end 

  def get_lines_avatars({:by_num, from_id, num}) do
    from_id..(from_id + num)
    |> Enum.map(fn id ->
      Guid.whereis(id)
    end)
    |> Enum.filter(&(is_pid(&1)))
  end 

  def get_lines_avatars({:by_range, range}) when is_list(range) do
    range
    |> Enum.map(fn id ->
      Guid.whereis(id)
    end)
    |> Enum.filter(&(is_pid(&1)))
  end 

  def get_lines_avatars({:by_slice, num}) do
    get_lines_avatars(:all)
    |> Enum.chunk_every(num)
  end

  def get_lines_avatars(:all) do
    from_id = StartConfig.start_id()
    chat_robot_num = StartConfig.chat_robot_num()
    end_id = case StartConfig.strategy() do
      'interval' ->
        interval_config = StartConfig.enter_array()
        enter_num = interval_config[:enter_num] || 0
        account_time = interval_config[:account_time] || 0
        from_id + chat_robot_num + enter_num * account_time
      'once_time' ->
        from_id + chat_robot_num + StartConfig.robot_num()
      'by_addition' ->
        interval_config = StartConfig.enter_array()
        addition = interval_config[:addition] || 0
        account_time = interval_config[:account_time] || 0
        slices = (account_time == 0) && 0 || Enum.count(1..account_time)
        from_id + chat_robot_num + addition * slices
      _ -> 
        from_id + chat_robot_num
    end
    from_id..end_id
    |> Enum.map(fn id ->
      Guid.whereis(id)
    end)
    |> Enum.filter(&(is_pid(&1)))
  end

  def get_lines_avatars(:chat) do
    from_id = StartConfig.start_id()
    chat_robot_num = StartConfig.chat_robot_num()
    from_id..(from_id + chat_robot_num - 1)
    |> Enum.map(fn id ->
      Guid.whereis(id)
    end)
    |> Enum.filter(&(is_pid(&1)))
  end

  def shutdown() do
    Process.sleep(5000)
    Supervisor.stop(Avatars)
  end

end
