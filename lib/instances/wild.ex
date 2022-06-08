defmodule Wild do
  
  def enter(lines \\ :all) do
    ["change_scene", 2010]
    |> Realm.broadcast_avatars(lines)
  end

end