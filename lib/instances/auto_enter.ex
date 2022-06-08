defmodule AutoEnter do
  use GameDef
  @warfare_map_ids GameDef.load_rows("activities/territory_warfare")
  |> Enum.map(&(&1["value"]["map"]))

  def auto_enter(tag, player) do
    msgs = 
    cond do
      #[107, 116, 117, 118, 119]
      107 ->
        [["mind_quiz:player_enter"]]
      116 ->
        [["battle_field:player_enter"]]
      117 ->
        [["short_treasure:player_enter"]]
      118 ->
        [["group:enter_home"], ["group_party:player_enter"]]
      119 ->
        [["mind_quiz:player_enter"]]
      125 ->
        enter_map_id = get_enter_map(125, player)
        [["territory_warfare:player_enter", enter_map_id]]
      tag in  Application.get_env(:pressure_test, :auto_enter_heas, []) ->
        []
      true ->
        []
    end
    
    Enum.each(msgs, fn mm ->
      # start_time = Utils.timestamp(:ms)
      Client.send_msg(player.conn, mm)
      # end_time = Utils.timestamp(:ms)
      # Upload.trans_info("auto enter #{tag}", end_time - start_time, Utils.timestamp())
      Process.sleep(200)
    end)
  end

  def get_enter_map(id, player) do
    case id do
      125 ->
        # @warfare_map_ids |> Enum.at(Integer.mod(player.id, length(@warfare_map_ids)))
        Integer.mod(player.id, length(@warfare_map_ids)) + 1
      _ ->
        1010
    end
  end

end