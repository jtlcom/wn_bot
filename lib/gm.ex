defmodule Gm do
  
  def openact(act_id, time \\ 600) do
    ["gm:open_act", act_id, time]
    |> Realm.sendto_server_by_one_of_avatars()
  end

  def reply(msg) do
    Realm.sendto_server_by_one_of_avatars(msg)
  end

end