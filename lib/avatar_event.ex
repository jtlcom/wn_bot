defmodule AvatarEvent do
  require Logger

  def changed_update(player, changed) do
    Enum.reduce(changed, player, fn
      {key, data}, player_acc when is_binary(key) ->
        key = key |> String.to_atom()
        if Map.has_key?(player_acc, key), do: Map.put(player_acc, key, data), else: player_acc

      {key, data}, player_acc when is_atom(key) ->
        if Map.has_key?(player_acc, key), do: Map.put(player_acc, key, data), else: player_acc

      _, player_acc ->
        player_acc
    end)
  end

  def verse_update(player, type, verse_data) do
    case type do
      :units -> player |> Map.put(:units, Map.merge(player.units, verse_data))
      :fixed_units -> player |> Map.put(:fixed_units, Map.merge(player.fixed_units, verse_data))
      _ -> player
    end
  end

  def handle_info(["login:choose_born_state", _id, _params], %{gid: born_state} = player) do
    Upload.log("player: #{inspect(player)}")
    Client.send_msg(player.conn, ["login:choose_born_state", born_state])
    {player}
  end

  def handle_info(other_info, player) do
    Upload.log("info: #{inspect(other_info)}")
    {player}
  end

  def handle_event(["prop_changed", _id, changed], player) do
    IO.puts("new prop_changed  new new new !")
    player |> changed_update(changed)
  end

  def handle_event(["units", _, units_data], player) do
    IO.puts("new units  new new new !")
    player |> verse_update(:units, units_data)
  end

  def handle_event(other, player) do
    case other do
      [head | _] ->
        Logger.info("#{player.account} other_head : #{inspect(head, pretty: true)}!")
        player

      _ ->
        player
    end
  end
end
