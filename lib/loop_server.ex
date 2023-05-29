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
    GenServer.start_link(__MODULE__, :ok, name: name)
  end

  def init(:ok) do
    {:ok, %{state: :wait, count: 0}}
  end

  def handle_info(:stop, _state) do
    Logger.info("stop LoopServer server !!!")
    {:noreply, %{state: :wait}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.info("LoopServer terminate, reason : #{reason} !!!")
  end

  def do_loop() do
    SimpleStatistics.analyse()
    :ok
  end
end
