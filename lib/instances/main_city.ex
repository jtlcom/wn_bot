defmodule MainCity do
  
  def enter(lines \\ :all) do
    ["change_scene", 1010]
    |> Realm.broadcast_avatars(lines)
  end

end