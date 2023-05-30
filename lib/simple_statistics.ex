defmodule SimpleStatistics do
  @analyse :analyse_infos
  @events :events
  @onlines :onlines
  @total_num :total_num
  @infos :infos

  def get_total_num() do
    get_value(@total_num)
  end

  def get_onlines() do
    max(get_value(@onlines), 0)
  end

  def init_ets() do
    :ets.new(@analyse, [:set, :public, :named_table])
    :ets.new(@events, [:public, :named_table])
    :ets.insert(@analyse, {@infos, []})
    :ets.insert(@analyse, {@onlines, -1})
    :ets.insert(@analyse, {@total_num, 0})
  end

  defp get_value(key) do
    Keyword.get(:ets.lookup(@analyse, key), key)
  end

  defp save_value(key, infos) do
    :ets.insert(@analyse, {key, infos})
  end

  def update_infos(infos) do
    save_value(@infos, infos)
  end

  def update_total_num(num) do
    save_value(@total_num, num)
  end

  def insert_events(evt) when is_tuple(evt) do
    evt = Tuple.insert_at(evt, 0, System.unique_integer([:positive, :monotonic]))
    :ets.insert(@events, evt)
  end

  def insert_events(_) do
    :ok
  end

  def get_all_events() do
    :ets.tab2list(@events)
  end
end
