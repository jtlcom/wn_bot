defmodule SceneConfig do
  require Utils
  require Logger
  use GameDef
  
  #----------------------------------------------
  # modified: zgd 2018 05 09
  # for: 添加活动ID到地图ID的映射表/获取函数
  GameDef.load_rows("scene/map") |> Enum.reduce({[], %{}}, fn(x, {id_list, _act_map_ids}) ->
    map_id = x["key"]
    config = x["value"] |> GameDef.to_atom_key

    # {act_config, act_map_ids} = case config[:activityId] do
    #                               nil ->
    #                                 {%{}, act_map_ids}

    #                               act ->
    #                                 act_config = (Activity.Cfgs.get(act) || %{})
    #                                 |> Map.take([:enterType, :times, :enterConsume, :rewardTimes, :shouldReturn, :requireFunc])
    #                                 |> Map.update(:enterConsume, [], &GameDef.to_tagged_tuples/1)
                                    
    #                                 exist_map_ids = act_map_ids[act] || []
    #                                 act_map_ids = act_map_ids |> Map.put(act, [map_id | exist_map_ids])

    #                                 {act_config, act_map_ids}
    #                             end

    {act_config, act_map_ids} = {%{}, []}

    def get(unquote(map_id)), do: unquote(Macro.escape(Map.merge(config, act_config)))

    {[map_id | id_list], act_map_ids} #构建all_ids列表, 及活动的地图索引
  end)
  |> fn {id_list, act_map_ids} ->
    def get_all(), do: unquote(id_list)
    
    act_map_ids |> Enum.each(fn {act_id, map_ids} ->
      def get_activity_map_id(unquote(act_id)), do: unquote(map_ids)
    end)

    def get_activity_map_id(act_id) do
      Logger.debug fn -> "SceneConfig:get_activity_map_id no matched map for #{act_id}" end
      nil
    end
  end.()
  
  #----------------------------------------------
  GameDef.load_rows("scene/recover") |> Enum.map(fn %{"value" => v} ->
    %{pair: [from, to], actions: actions} = v = GameDef.to_atom_key(v)
    buffs = Map.get(v, :buffs, [])
    actions = Enum.map(actions, &Utils.to_atom/1)
    for f <- from do
      for t <- to do
        def recover(unquote(f), unquote(t)), do: %{actions: unquote(actions), buffs: unquote(buffs)}
      end
    end
  end)

  #----------------------------------------------
  def recover(_, _), do: %{actions: [], buffs: []}
end
