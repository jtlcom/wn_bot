defmodule WildBossZone do
  @level_limit 300
  use GameDef
  GameDef.defconf view: "activities/field_expedition"
  @all_mon_poses GameDef.load_rows("activities/field_expedition")
  |> Enum.map(&GameDef.to_atom_key/1)

  |> Enum.map(fn cfg ->
    poses = cfg[:value][:positions]
    poses |> Enum.map(&List.to_tuple/1)
  end)
  |> List.flatten()
  
  def enter(scene, lines \\ :all) do
    ["gm:level", @level_limit]
    |> Realm.broadcast_avatars(lines)
    Process.sleep(1000)
    ["wild_boss_zone:enter", scene]
    |> Realm.broadcast_avatars(lines)
  end

  def change_pos(x, y, lines \\ :all) do
    Tool.change_pos(x, y, lines)
  end

  def change_pos_random(lines \\ :all) do
    {:change_pos_random, __MODULE__}
    |> Realm.broadcast_avatars_handle(lines)
  end

  def get_pos_random() do
    @all_mon_poses |> Enum.random()
  end

end