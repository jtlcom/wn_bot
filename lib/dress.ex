defmodule Dress do
  use GameDef
  
  @dresses_by_class GameDef.load_rows("actors/c_dress")
  |> Enum.group_by(&(&1["value"]["Class"]), &({&1["key"], &1["value"]["DressType"], &1["value"]["MaterialId"]}))    # %{1 => [{id, act_item_id}, ...]}

  def dresses_by_class, do: @dresses_by_class

  def items(class) do
    (@dresses_by_class[class] || [])
    |> Enum.reject(fn {d_id, _, _} -> rem(d_id, 10) == 1 end)
    |> Enum.reduce({[], [], []}, fn {dress_id, dre_type, material}, {add, active, wear} ->
      {add ++ [["gm:add_item", material, 10]], active ++ [["dresses:active", get_type(dre_type), dress_id]], wear ++ [["dresses:wear", get_type(dre_type), dress_id]]}
    end)
  end

  def dresss(player) do
    start_time = Utils.timestamp(:ms)
    (@dresses_by_class[player.class] || [])
    # |> Enum.reject(fn {d_id, _, _} -> rem(d_id, 10) == 1 end) # 过滤默认外观
    |> Enum.group_by(&(elem(&1, 1)), &(elem(&1, 0)))
    |> Enum.map(&({elem(&1, 0), elem(&1, 1) |> Enum.random}))
    |> Enum.map(fn {dre_type, d_id} ->
      Client.send_msg(player.conn, ["dresses:wear", get_type(dre_type), d_id])
      # Process.sleep(100)
      {get_type(dre_type), d_id}
    end)
    end_time = Utils.timestamp(:ms)
    Upload.trans_info("dresses:wear", end_time - start_time, Utils.timestamp())
  end

  def get_type(ty) do
    case ty do
      2 ->
        "dress"
      1 ->
        "shapes"
    end
  end

end