defmodule ShortTreasure do

  def enter(lines \\ :all) do
    ["short_treasure:player_enter"]
    |> Realm.broadcast_avatars(lines)
  end

  def leave(lines \\ :all) do
    ["short_treasure:player_leave"]
    |> Realm.broadcast_avatars(lines)
  end
  
end