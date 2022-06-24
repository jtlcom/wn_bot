defmodule Gm do

  def openact(act_id, time \\ 600) do
    ["gm:open_act", act_id, time]
    |> Realm.sendto_server_by_one_of_avatars()
  end

  def reply(msg) do
    Realm.sendto_server_by_one_of_avatars(msg)
  end

  def s() do
    Realm.broadcast({:show_data})
  end

  def s(key) do
    Realm.broadcast({:show_data, key})
  end

  def atk() do
    Realm.broadcast({:atk})
  end

  def gacha(num) do
    Realm.broadcast({:gacha, num})
  end
end
