defmodule Router do
  
  def cast(name, request) when is_atom(name) do
    GenServer.cast(name, request)
  end

  def cast(pid, request) when is_pid(pid) do
    GenServer.cast(pid, request)
  end

  def cast(guid, request) do
    GenServer.cast({:global, {:name, Guid.name(guid)}}, request)
  end

  def call(name, request) when is_atom(name) do
    GenServer.call(name, request, 1000)
  end

  def call(pid, request) when is_pid(pid) do
    GenServer.call(pid, request, 1000)
  end

  def call(guid, request) do
    GenServer.call({:global, {:name, Guid.name(guid)}}, request)
  end

  def route(guid, request), do: cast(guid, request)

  def query(guid, id, path), do: call(guid, {:query, id, path})

  def notify(guid, event), do: cast(guid, {:notify, event})

end
