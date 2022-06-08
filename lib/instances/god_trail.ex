defmodule GodTrial do
  
  def enter(lines \\ :all) do
    ["god_trial:chanllenge"]
    |> Realm.broadcast_avatars(lines)
  end

end