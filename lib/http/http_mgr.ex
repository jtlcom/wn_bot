defmodule HttpMgr do
  use HandlerWorkerAPI, name: __MODULE__

  def init(_) do
    Process.send_after(self(), :loop, 5000)
    {:ok, %{}}
  end

  def handle_info(:loop, state) do
    # Logger.info("HttpMgr HttpMgr HttpMgr")
    Process.send_after(self(), :loop, 5000)
    {:noreply, state}
  end
end
