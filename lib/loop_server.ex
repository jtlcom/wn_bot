defmodule LoopServer.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(LoopServer, [LoopServer], restart: :transient)
    ]
    supervise(children, strategy: :one_for_one)
  end

end

defmodule LoopServer do

  use GenServer
  use Bitwise
  require Logger
  # alias Crontab.CronExpression.Parser
  @per_sec 1

  def start_link(name) do
    GenServer.start_link(__MODULE__, :ok, [name: name])
  end

  def init(:ok) do    
    {:ok, %{state: :wait, count: 0}}
  end

  def handle_info(:start, state) do
    Process.send_after(self(), :enter_frame, 1000)
    {:noreply, state |> Map.merge(%{state: :start})}
  end

  def handle_info(:enter_frame, %{state: :start} = state) do
    do_loop()
    Process.send_after(self(), :enter_frame, @per_sec * 1000)
    {:noreply, state}
  end
  
  def handle_info(:msg_begin_together, state) do
    # IO.inspect "broadcast msg_begin_together!"
    # # Realm.broadcast(:msg_begin_together)
    # need_group = Application.get_env(:pressure_test, :need_group, false)
    # IO.inspect "create group"
    # need_group && Group.create_group({:by_num, Application.get_env(:pressure_test, :create_group_num, 100)})
    # IO.inspect "join group"
    # need_group && Group.join_group_by_index(Application.get_env(:pressure_test, :from_group_index, 0))
    IO.inspect "auto msg reply begin together ~~~"
    Realm.broadcast_all_interval(:msg_begin_together, Application.get_env(:pressure_test, :per_enter, 1), 50)
    {:noreply, state}
  end

  def handle_info(:start_move, state) do
    IO.inspect "start move"
    # Realm.broadcast(:msg_begin_together)
    # Realm.broadcast_all_interval({:set_robot_state, 0}, 200, 1000)
    Tool.move()
    {:noreply, state}
  end

  def handle_info(:stop, _state) do
    Logger.info "stop LoopServer server !!!"
    {:noreply, %{state: :wait}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.info "LoopServer terminate, reason : #{reason} !!!"
  end

  def do_loop() do
    SimpleStatistics.analyse()
    :ok
  end

end
