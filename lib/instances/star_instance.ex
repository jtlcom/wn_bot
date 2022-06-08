defmodule StarInstance do
  
  def enter(lines \\ :all) do
    ["change_scene", 1, 102111]
    |> Realm.broadcast_avatars_delay(lines, 200)
  end

end