defmodule WorldBoss do
  
  def enter(lines \\ :all) do
    ["change_scene", 1, 405001]
    |> Realm.broadcast_avatars(lines)
  end

end