## 场景存储结构 进程字典方式
## 玩家 map
## 怪物 map

## spell list
defmodule SceneData do

  require Logger
  
  # @player_type 1
  # def player_type, do: @player_type
  # @monster_type 2
  # def monster_type, do: @monster_type

  @player_dic :player_dic
  @monster_dic :monster_dic
  @drop_dic :drop_dic
  @collect_dic :collect_dic

  def del_all_entity() do
    get_all_entity()
    |> Enum.each(fn id ->
      Process.delete {:entity, id}
    end)
    :erlang.put(@player_dic, [])
    :erlang.put(@monster_dic, [])
    :erlang.put(@drop_dic, [])
    :erlang.put(@collect_dic, [])
  end

  def update_entity(sn, changed) do
    prev_entity = Process.get {:entity, sn}
    cond do
      sn in get_all_entity() && prev_entity ->
        Process.put {:entity, sn}, Map.merge(prev_entity, changed)
      true ->
        # Logger.info "what's this sn: #{sn} ???"
        :ok
    end
  end

  def save_entity(%{id: id} = entity) do
    Process.put {:entity, id}, entity
  end

  def get_entity_by_id(id) do
    Process.get({:entity, id})
  end

  def delete_entity(id) do
    Process.delete {:entity, id}
    delete_player_from_list(id)
    del_monster_from_list(id)
    del_drop(id)
    del_collect_from_list(id)
  end

  # players
  def save_player(player_id, player_data) do
    save_entity(player_data)
    add_player_to_list(player_id)
  end

  def add_player_to_list(id) do
    old_list = get_all_player()
    unless id in old_list do
      Process.put(@player_dic, [id | old_list])
    end
  end

  def delete_player_from_list(id) do
    old_list = get_all_player()
    Process.put(@player_dic, List.delete(old_list, id))
  end

  # monsters
  def save_monster(mon_id, mon_data) do
    save_entity(mon_data)
    add_monster_to_list(mon_id)
  end

  def add_monster_to_list(id) do
    old_list = get_all_monster()
    unless id in old_list do
      Process.put(@monster_dic, [id | old_list])
    end
  end

  def del_monster_from_list(id) do
    old_list = get_all_monster()
    Process.put(@monster_dic, List.delete(old_list, id))
  end

  # collect
  def save_collect(coll_id, coll_data) do
    save_entity(coll_data)
    add_collect_to_list(coll_id)
  end

  def add_collect_to_list(id) do
    old_list = get_all_collect()
    unless id in old_list do
      Process.put(@collect_dic, [id | old_list])
    end
  end

  def del_collect_from_list(id) do
    old_list = get_all_collect()
    Process.put(@collect_dic, List.delete(old_list, id))
  end

  # drop
  def save_drop(drop_list) do
    get_all_drop() |> Enum.concat(drop_list) |> save_drop_map
  end

  def del_drop(drop_id) do
    get_all_drop() |> Enum.reject(fn %{id: d_id} -> drop_id == d_id end) |> save_drop_map
  end

  def save_drop_map(value) do
    Process.put(@drop_dic, value)
  end

  #####################
  def get_all_player() do
    Process.get(@player_dic, [])
  end

  def get_all_monster() do
    Process.get(@monster_dic, [])
  end

  def get_all_drop() do
    Process.get(@drop_dic, [])
  end
  
  def get_all_collect() do
    Process.get(@collect_dic, [])
  end

  def get_all_collect_entities() do
    Process.get(@collect_dic, []) |> Enum.map(&SceneData.get_entity_by_id/1)
  end
  ############################
  def get_player_by_id(player_id) do
    get_entity_by_id player_id
  end

  def get_monster_by_id(mon_id) do
    get_entity_by_id mon_id
  end

  def get_all_entity() do
    get_all_player() 
    |> Enum.concat(get_all_monster())
  end

  def get_all_entity_without_player(id) do
    get_all_player()
    |> List.delete(id)
    |> Enum.concat(get_all_monster())
  end

  def save_scene_id(id) do
    Process.put(:scene_id_dic, id)
  end

  def get_scene_id() do
    Process.get(:scene_id_dic)
  end
  
end
