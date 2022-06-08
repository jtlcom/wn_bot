defmodule Warfare do
  
  def enter(lines \\ :all) do
    ["territory_warfare:player_enter"]
    |> Realm.broadcast_avatars(lines)
  end

end