defmodule MnesiaMgr.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(MnesiaMgr, [])
    ]
    supervise(children, strategy: :one_for_one)
  end
end

defmodule MnesiaMgr do
  use GenServer
  require Logger
  @interval 100
  @name MnesiaMgr

  def start_link() do
    GenServer.start_link(__MODULE__, :ok, [name: @name])
  end

  def init(_) do
    Process.send_after(self(), :enter_frame, 50)
    {:ok, []}
  end

  def handle_info(:enter_frame, [{line_id, a_pid} | t] = _state) do
    # handle_delete
    prev_lines = Mnesiam.AvatarLines.get_data(:lines) || %{}
    # Logger.info "pid is #{inspect self()}, prev_lines is #{inspect prev_lines}"
    new_lines = Map.update(prev_lines, line_id, Map.get(prev_lines, line_id, []), fn line_avatars -> 
      Enum.reject(line_avatars, fn pid -> 
        pid == a_pid
      end) 
    end)
    |> Enum.reject(fn {_line_id, avatars} -> avatars == [] end) 
    |> Map.new()
    Mnesiam.AvatarLines.save_data(:lines, new_lines)
    Process.send_after(self(), :enter_frame, @interval)
    {:noreply, t}
  end
 
  def handle_info(:enter_frame, [] = _state) do
    Process.send_after(self(), :enter_frame, @interval)
    {:noreply, []}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_cast({:new_del, line_id, pid}, state) do
    # Logger.info "new del pid is : #{inspect {line_id, pid}}, state is : #{inspect state}"
    {:noreply, state ++ [{line_id, pid}]}
  end

  def handle_cast(_cast_info, state) do
    # Logger.info "cast info is : #{inspect cast_info}"
    {:noreply, state}
  end

  def terminate(reason, state) do
    Logger.info "MnesiaMgr terminate, reason is : #{inspect reason}, state is #{inspect state}"
  end

end
