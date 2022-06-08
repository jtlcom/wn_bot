defmodule BattleField do

  def enter(lines \\ :all) do
    ["battle_field:player_enter"]
    |> Realm.broadcast_avatars(lines)
  end

  def leave(lines \\ :all) do
    ["battle_field:player_leave"]
    |> Realm.broadcast_avatars(lines)
  end

end