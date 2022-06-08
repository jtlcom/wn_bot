defmodule GroupBattle do
  
  def enter(lines \\ :all) do
    ["group_battle:player_enter"]
    |> Realm.broadcast_avatars(lines)
  end

  def leave(lines \\ :all) do
    ["group_battle:player_leave"]
    |> Realm.broadcast_avatars(lines)
  end

end