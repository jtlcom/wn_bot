defmodule SprReport do
  def new_report(type, %AvatarDef{coll_report: c_report} = player) do
    now_ms = CommonAPI.timestamp(:ms)

    c_report =
      case type do
        "login:choose_born_state" ->
          c_report |> Map.put("login", %{mod: "RobotLoginNew", start_ms: now_ms})

        "login" ->
          cond do
            Map.has_key?(c_report, "login") -> c_report
            true -> c_report |> Map.put("login", %{mod: "RobotLogin", start_ms: now_ms})
          end

        "gacha:gacha" ->
          c_report |> Map.put("gacha:gacha", %{mod: "RobotLottery", start_ms: now_ms})

        "mail:detail" ->
          c_report |> Map.put("mail:detail", %{mod: "RobotMail", start_ms: now_ms})

        "mail:read_all" ->
          c_report |> Map.put("mail:read_all", %{mod: "RobotMail", start_ms: now_ms})

        "op" ->
          c_report |> Map.put("op", %{mod: "RobotBattle", start_ms: now_ms})

        "chat:send" ->
          c_report |> Map.put("chat:send", %{mod: "RobotChatWorld", start_ms: now_ms})

        _ ->
          c_report
      end

    struct(player, %{coll_report: c_report})
  end

  def new_report(_type, player), do: player

  def send_report(%AvatarDef{coll_report: c_report} = player, key) do
    now_ms = CommonAPI.timestamp(:ms)

    case Map.get(c_report, key) do
      %{mod: mod_name, start_ms: start_ms} ->
        SprAdapter.cast({:collect, mod_name, start_ms, now_ms})
        c_report = c_report |> Map.delete(key)
        struct(player, %{coll_report: c_report})

      _ ->
        player
    end
  end

  def send_report(player, _key), do: player
end
