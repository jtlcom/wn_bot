defmodule MsgCounter do
  # use Agent
  @ets_counter :ets_counter_ets

  # def start_link() do
  #   Agent.start_link(fn -> %{} end, name: __MODULE__)
  # end

  def init() do
    :ets.new(@ets_counter, [:set, :public, :named_table])
    :ets.insert(@ets_counter, {:recv_count, 0})
    :ets.insert(@ets_counter, {:res_count, 0})
    :ets.insert(@ets_counter, {:robot_num, 0})
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

  def recv_count_add() do
    # Agent.cast(__MODULE__, fn counter -> counter |> Map.update(:recv_count, 1, &(&1 + 1)) end)
    :ets.update_counter(@ets_counter, :recv_count, 1)
  end

  def res_count_add() do
    # Agent.cast(__MODULE__, fn counter -> counter |> Map.update(:res_count, 1, &(&1 + 1)) end)
    :ets.update_counter(@ets_counter, :res_count, 1)
  end

  def res_num_add() do
    # Agent.cast(__MODULE__, fn counter -> counter |> Map.update(:robot_num, 1, &(&1 + 1)) |> Map.update(:onlines_count, 1, &(&1 + 1))  end)
    :ets.update_counter(@ets_counter, :robot_num, 1)
    :ets.update_counter(@ets_counter, :onlines_count, 1)
  end

  def res_onlines_add() do
    # Agent.cast(__MODULE__, fn counter -> counter |> Map.update(:onlines_count, 1, &(&1 + 1)) end)
    :ets.update_counter(@ets_counter, :onlines_count, 1)
  end

  def res_onlines_sub() do
    # Agent.cast(__MODULE__, fn counter -> counter |> Map.update(:onlines_count, 0, &((&1 > 0) && (&1 - 1) || 0)) end)
    :ets.update_counter(@ets_counter, :onlines_count, -1)
  end

  def get_recv_count() do
    # Agent.get(__MODULE__, &(&1[:recv_count] || 0))
    :ets.lookup(@ets_counter, :recv_count) |> Keyword.get(:recv_count)
  end

  def get_res_count() do
    # Agent.get(__MODULE__, &(&1[:res_count] || 0))
    :ets.lookup(@ets_counter, :res_count) |> Keyword.get(:res_count)
  end

  def get_num_count() do
    # Agent.get(__MODULE__, &(&1[:robot_num] || 0))
    :ets.lookup(@ets_counter, :robot_num) |> Keyword.get(:robot_num)
  end

  def get_onlines_count() do
    # Agent.get(__MODULE__, &(&1[:onlines_count] || 0))
    :ets.lookup(@ets_counter, :onlines_count) |> Keyword.get(:onlines_count)
  end

  def take_counts() do
    # Agent.get(__MODULE__, &([&1[:recv_count] || 0, &1[:res_count] || 0, &1[:robot_num] || 0, &1[:onlines_count] || 0]))
    [get_recv_count(), get_res_count(), get_num_count(), get_onlines_count()]
  end

  # def report() do
  #   Agent.get(__MODULE__, fn counter ->
  #     Enum.sort_by(counter, &(elem(&1, 1)[:size]), &>=/2)
  #   end)
  # end
end
