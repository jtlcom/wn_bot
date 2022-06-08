defmodule GroupParty do
  
  def enter(lines \\ :all) do
    ["group:enter_home"]
    |> Realm.broadcast_avatars_delay(lines, 10)
    Process.sleep(1000)
    ["group_party:player_enter"]
    |> Realm.broadcast_avatars_delay(lines, 10)
  end

  def leave(lines \\ :all) do
    ["group_party:player_leave"]
    |> Realm.broadcast_avatars(lines)
  end

end