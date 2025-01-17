defmodule AvatarEvent do
  require Logger

  def changed_update(player, changed) do
    Enum.reduce(changed, player, fn
      {key, data}, player_acc when is_binary(key) ->
        struct(player_acc, %{String.to_atom(key) => data})

      {key, data}, player_acc when is_atom(key) ->
        struct(player_acc, %{key => data})

      _, player_acc ->
        player_acc
    end)
  end

  def verse_update(%AvatarDef{units: units} = player, :units, verse_data) do
    new_unit =
      Enum.reduce(verse_data, units, fn
        {aid_gid, pos_list}, acc ->
          case String.split(aid_gid, ",") do
            [aid, gid] ->
              aid = String.to_integer(aid)
              gid = String.to_integer(gid)
              unit_extra = %{"aid" => aid, "gid" => gid}

              this = Enum.flat_map(pos_list, fn pos -> [{pos, unit_extra}] end) |> Map.new()
              acc |> Map.merge(this)

            _ ->
              acc
          end

        _, acc ->
          acc
      end)

    struct(player, %{units: new_unit})
  end

  def verse_update(%AvatarDef{fixed_units: fixed_units} = player, :fixed_units, verse_data) do
    new_fixed_units =
      Enum.reduce(verse_data, fixed_units, fn
        %{"pos" => pos} = this, acc ->
          acc |> Map.update(pos, this, &Map.merge(&1, this))

        _, acc ->
          acc
      end)

    struct(player, %{fixed_units: new_fixed_units})
  end

  def verse_update(%AvatarDef{dynamic_units: dynamic_units} = player, :dynamic_units, verse_data) do
    new_dynamic_units =
      Enum.reduce(verse_data, dynamic_units, fn
        {this_guid, this_data}, acc ->
          acc |> Map.put(this_guid, this_data)

        _, acc ->
          acc
      end)

    struct(player, %{dynamic_units: new_dynamic_units})
  end

  def verse_update(player, _type, _verse_data), do: player

  def handle_event(["prop_changed", _id, changed], player) do
    player |> changed_update(changed)
  end

  def handle_event(["avatar_data", _id, changed], player) do
    player |> changed_update(changed)
  end

  def handle_event(["units", _, units_data], player) do
    player |> verse_update(:units, units_data)
  end

  def handle_event(["fixed_units", _, fixed_units_data], player) do
    player |> verse_update(:fixed_units, fixed_units_data)
  end

  def handle_event(["fixed_unit_changed", _, fixed_units_data], player) do
    player |> verse_update(:fixed_units, fixed_units_data)
  end

  def handle_event(["dynamic_units", _, dynamic_units_data], player) do
    player |> verse_update(:dynamic_units, dynamic_units_data)
  end

  def handle_event(["add_grid", _, grid_data, _ms_time], %AvatarDef{grids: grids} = player) do
    new_grids = grids |> Map.merge(grid_data)
    struct(player, %{grids: new_grids})
  end

  def handle_event(["hero_changed", _, hero_data], %AvatarDef{heros: heros} = player) do
    new_heros =
      Enum.reduce(hero_data, heros, fn
        {hero_guid, new_data}, acc ->
          case Map.get(heros, hero_guid) do
            %{} = prev_hero ->
              acc |> Map.put(hero_guid, Map.merge(prev_hero, new_data))

            _ ->
              acc
          end

        _, acc ->
          acc
      end)

    struct(player, %{heros: new_heros})
  end

  def handle_event(
        ["mail:list", _, %{"system" => new_mails}],
        %AvatarDef{system_mails: prev_sys_mails} = player
      ) do
    new_sys_mails =
      Enum.reduce(new_mails, prev_sys_mails, fn
        %{"id" => mail_id, "got" => false} = this_mail, acc ->
          acc |> Map.put(mail_id, this_mail)

        _, acc ->
          acc
      end)

    struct(player, %{system_mails: new_sys_mails})
  end

  def handle_event(
        [
          "chat:server_info",
          _,
          %{
            "port" => _port,
            "ip" => _ip,
            "password" => _password,
            "client_id" => _client_id,
            "topics" => new_topics
          } = server_info
        ],
        %AvatarDef{chat_data: chat_data} = player
      ) do
    new_topics =
      new_topics
      |> Enum.reduce(Map.get(chat_data, "topics", %{}), fn topic, acc ->
        if not Map.has_key?(acc, topic) do
          if String.match?(topic, ~r/^family/) do
            acc
            |> Enum.filter(fn {k, v} ->
              if String.match?(k, ~r/^family/) do
                conn = Process.get(:mqtt_conn)
                v && conn != nil && MQTT.Client.unsubscribe(conn, k)
                false
              else
                true
              end
            end)
            |> Map.new()
          else
            acc
          end
          |> Map.put(topic, false)
        else
          acc
        end
      end)

    new_chat_data = server_info |> Map.put("topics", new_topics)
    struct(player, %{chat_data: new_chat_data})
  end

  def handle_event(["gacha:gacha" | _], player) do
    SprReport.send_report(player, "gacha:gacha")
  end

  def handle_event(["mail:detail" | _], player) do
    SprReport.send_report(player, "mail:detail")
  end

  def handle_event(["mail:read_all" | _], player) do
    SprReport.send_report(player, "mail:read_all")
  end

  def handle_event(["op" | _], player) do
    SprReport.send_report(player, "op")
  end

  def handle_event(["chat:send" | _], player) do
    SprReport.send_report(player, "chat:send")
  end

  def handle_event(["tile_detail" | _], player) do
    SprReport.send_report(player, "see")
  end

  def handle_event(["pay:midas_buy_goods" | _], player) do
    SprReport.send_report(player, "pay:midas_buy_goods")
  end

  def handle_event(_other, player) do
    player
  end
end
