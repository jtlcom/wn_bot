defmodule ChangeScene do

  def go(scene, lines \\ :all) do
    ["change_scene", scene]
    |> Realm.broadcast_avatars(lines)
  end

end