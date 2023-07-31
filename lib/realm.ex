defmodule Realm do
  require Logger

  def control(avatar, request) do
    GenServer.cast(avatar, request)
  end

  def broadcast_each_delay(msg, delay \\ 0) do
    Supervisor.which_children(Avatars)
    |> Enum.each(fn {_, pid, _, _} ->
      # spawn(fn ->
      GenServer.cast(pid, msg)
      delay > 0 && Process.sleep(delay)
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

  def shutdown() do
    Process.sleep(5000)
    Supervisor.stop(Avatars)
  end
end
