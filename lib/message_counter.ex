defmodule MsgCounter do
  # use Agent
  @ets_counter :ets_counter_ets

  # def start_link() do
  #   Agent.start_link(fn -> %{} end, name: __MODULE__)
  # end

  def init() do
    :ets.new(@ets_counter, [:set, :public, :named_table])
    :ets.insert(@ets_counter, {:onlines_count, 0})
  end

  # def count(type, tag, cat, size) do
  #   Agent.cast(__MODULE__, fn counter ->
  #     counter |> Map.update("#{type}:#{tag}:#{cat}", %{cat: cat, count: 1, size: size}, fn counter ->
  #       counter
  #       |> Map.update!(:count, &(&1 + 1))
  #       |> Map.update!(:size, &(&1 + size))
  #     end)
  #   end)
  # end

  def res_onlines_add() do
    # Agent.cast(__MODULE__, fn counter -> counter |> Map.update(:onlines_count, 1, &(&1 + 1)) end)
    :ets.update_counter(@ets_counter, :onlines_count, 1)
  end

  def res_onlines_sub() do
    # Agent.cast(__MODULE__, fn counter -> counter |> Map.update(:onlines_count, 0, &((&1 > 0) && (&1 - 1) || 0)) end)
    :ets.update_counter(@ets_counter, :onlines_count, -1)
  end

  def get_onlines_count() do
    # MsgCounter.get_onlines_count
    # Agent.get(__MODULE__, &(&1[:onlines_count] || 0))
    :ets.lookup(@ets_counter, :onlines_count) |> Keyword.get(:onlines_count)
  end

  # def report() do
  #   Agent.get(__MODULE__, fn counter ->
  #     Enum.sort_by(counter, &(elem(&1, 1)[:size]), &>=/2)
  #   end)
  # end
end
