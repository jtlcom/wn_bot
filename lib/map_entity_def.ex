defmodule MapEntityType do

  def player_type, do: 0

  def monster_type, do: 1

  def pet_type, do: 2

  def npc_type, do: 3

  def object_type, do: 4

  ## 离线玩家，假人
  def virtual_type, do: 5

  ## 召唤物
  def summon_type, do: 6

  ## 召唤物
  def drop_type, do: 7

  ## 法术场
  def spell_field_type, do: 8

  def robot_needed_types() do
    [1, 4]
  end

end