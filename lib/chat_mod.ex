defmodule ChatMod.Supervisor do
  use Supervisor
  @name WeTestApis
  @chat_mod_supervisior ChatMod.Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: @chat_mod_supervisior)
  end

  def start_child(args, opts \\ []) do
    Supervisor.start_child(@name, [args, opts])
  end

  def init(_) do
    children = [
      worker(ChatMod, [ChatMod], restart: :transient)
    ]

    supervise(children, strategy: :one_for_one)
  end
end

defmodule ChatMod do
  require Logger
  use GenServer

  # @loop_time 5000
  @msg_broadcast ["*+*", "(*><*)", "^_^", "^@^", "->_->"]

  def start_link(_name) do
    GenServer.start_link(__MODULE__, :ok, name: :chat_mod_pid)
  end

  def init(:ok) do
    # Process.send_after(self(), :loop, 25000)
    {:ok, []}
  end

  def handle_cast({:msg, msg_info}, state) do
    # Chat.Mgr.dispatch(:all, msg_info)
    {:noreply, [msg_info | state]}
  end

  def handle_cast({:connect, socket}, state) do
    # Chat.Mgr.dispatch(:all, msg_info)
    {:noreply, [socket | state]}
  end

  def handle_cast(what, state) do
    Logger.warn("what is #{inspect(what)}")
    # Chat.Mgr.dispatch(:all, msg_info)
    {:noreply, state}
  end

  def handle_info(:loop, state) do
    # list = Enum.take(state, 13)

    fun = fn conn ->
      Client.send_msg(conn, [
        "msg:world",
        Application.get_env(:pressure_test, :msg_broadcast, @msg_broadcast) |> Enum.random()
      ])

      Upload.trans_info("msg:world", Enum.random(100..856), Utils.timestamp())
    end

    Enum.each(state, fun)
    Process.send_after(self(), :loop, 20000)

    {:noreply, state}
  end
end
