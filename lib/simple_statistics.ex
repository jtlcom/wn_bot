defmodule SimpleStatistics do
  alias Lala.Event
  @analyse :analyse_infos
  @events :events
  @onlines :onlines
  @total_num :total_num
  @infos :infos
  
  def get_infos() do
    get_value(@infos)
    |> Enum.map(fn {e1, e2, e3, e4, e5, e6, e7, e8, e9, e10} ->
      %Event{
        eid: e1,
        name: e2,
        count: e3,
        max_consume: e4,
        min_consume: e5,
        avg_consume: e6,
        fifty: e7,
        seventy_five: e8,
        ninty: e9,
        ninty_five: e10
      }
    end)
    |> Enum.reject(&is_nil/1)
  end

  def get_total_num() do
    get_value(@total_num)
  end

  def get_onlines() do
    max(get_value(@onlines), 0)
  end

  def analyse() do
    get_all_events()
    |> Enum.group_by(&(elem(&1, 1)), &(elem(&1, 2)))
    |> Enum.reduce({[], 1}, fn {title, times}, {infos, index} ->
      times = times |> Enum.sort()
      len = length(times)
      [i1, i2, i3, i4] = Enum.map([0.5, 0.75, 0.9, 0.95], fn percent ->
        Enum.at(times, trunc(len * percent) - 1)
      end)
      info = {index, title, len, Enum.at(times, -1), Enum.at(times, 0), Float.ceil((Enum.sum(times) / len), 3), i1, i2, i3, i4}
      {[info] ++ infos, index + 1}
    end)
    |> elem(0)
    |> Enum.reverse()
    |> update_infos()
    Upload.log_analyse()
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

  def update_onlies(addition) do
    # IO.inspect addition]
    (addition > 0) && Upload.log("update_onlies, new robot num: #{addition}")
    type = @onlines
    if :ets.lookup(@analyse, type) == [] do
      :ets.insert(@analyse, {type, 0})
    end
    :ets.update_counter(@analyse, type, addition)
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