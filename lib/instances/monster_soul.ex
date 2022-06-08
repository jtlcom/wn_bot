defmodule MonsterSoul do
  
  def test(id, num, lines \\ :all) do
    ["gm:add_item", id, num]
    |> Realm.broadcast_avatars_delay(lines, 1)
  end

end