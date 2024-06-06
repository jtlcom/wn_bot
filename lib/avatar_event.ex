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

  def handle_event(other, player) do
    case other do
      [head | _] ->
        # Logger.debug("#{player.account} other_head : #{inspect(head, pretty: true)}!")
        player

      _ ->
        player
    end
  end
end
