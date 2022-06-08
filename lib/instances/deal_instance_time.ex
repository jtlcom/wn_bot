defmodule DealInstanceTime do
  require Logger

  def init_instance_time() do
    ProcessMap.put_dict(%{fight_time: 0})
  end

  def instance_time_head() do
    [
      "short_treasure:time_info"

    ]
  end
  
  def deal_time_msg(msg) do
    # fight_time 为秒
    # Logger.info "#{inspect msg}"
    fight_time = case msg do        #转换成秒
      ["short_treasure:time_info", _, %{"begin_time" => _begin_time, "end_time" => end_time}] ->
        end_time
      ["battle_field:time_info", _, %{"begin_time" => _begin_time, "end_time" => end_time}] ->
        end_time

      _ ->
        0
    end
    ProcessMap.put_dict(%{fight_time: fight_time})
  end

  def if_time_over?() do
    fight_time = ProcessMap.from_dict(:fight_time)
    fight_time > 0 && Utils.timestamp() >= fight_time 
  end

end