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

  def verse_update(player, type, verse_data) do
    case type do
      :units -> player |> Map.put(:units, Map.merge(player.units, verse_data))
      :fixed_units -> player |> Map.put(:fixed_units, Map.merge(player.fixed_units, verse_data))
      _ -> player
    end
  end

  def handle_event(["prop_changed", _id, changed], player) do
    player |> changed_update(changed)
  end

  def handle_event(["avatar_data", _id, changed], player) do
    player |> changed_update(changed)
  end

  def handle_event(["units", _, units_data], player) do
    player |> verse_update(:units, units_data)
  end

  def handle_event(["fixed_units", _, units_data], player) do
    player |> verse_update(:fixed_units, units_data)
  end

  def handle_event(["fixed_unit_changed", _, units_data], player) do
    player |> verse_update(:fixed_units, units_data)
  end

  def handle_event(["add_grid", _, grid_data, _ms_time], %AvatarDef{grids: grids} = player) do
    new_grids = grids |> Map.merge(grid_data)
    struct(player, %{grids: new_grids})
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
        Logger.debug("#{player.account} other_head : #{inspect(head, pretty: true)}!")
        player

      _ ->
        player
    end
  end
end
