defmodule Shop do
  
  def query_shop(lines \\ :all) do
    # 查询后会自动购买
    [["shop:list", 101], ["shop:list", 102]]
    |> Enum.reduce(fn msg, delay ->
      Realm.broadcast_avatars_delay(msg, lines, delay)
      delay + 1000
    end)
  end

end