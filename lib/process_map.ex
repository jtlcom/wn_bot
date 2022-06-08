defmodule ProcessMap do
  
  # ------------------
  def put_dict(dict) when is_map(dict) do
    Enum.each(dict, fn {k, v} ->
        Process.put(k, v)
    end)
  end

  def put_dict(k, v) do
    Process.put(k, v)
  end

  def from_dict(k) when is_atom(k) do
    Process.get(k)
  end

  def from_dict(keys) when is_list(keys) do
    Enum.reduce(keys, %{}, fn k, map ->
      Map.put(map, k, Process.get(k))
    end)
  end

end