defmodule BossHome do
  
  def enter(lines \\ :all) do
    ["change_scene", 1, 411001]
    |> Realm.broadcast_avatars(lines)
  end

end