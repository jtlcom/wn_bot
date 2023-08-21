defmodule AvatarLoop do
  require Logger

  # def loop(player) do
  #   now_time = System.system_time(:millisecond)

  #   if is_active(player, now_time) do
  #     {:ok, do_loop(player, now_time)}
  #   else
  #     player
  #   end
  # end

  # -----------------
  # 机器人仿真执行逻辑
  #
  # 必定执行：
  # 1. 主城是否存在被攻击的威胁?如果是,全队回城
  # 2. 驻外部队是否存在被敌军克制的威胁?如果是,一半的概率回城,一半概率头铁
  # 3. 驻外部队兵力是否低于上限的一半?如果是,队伍回城
  # 按心情执行: (每次循环有一半的概率执行以下其一)
  # 4. 主城周围是否存在打的过的敌军,如果是,打他
  # 5. 驻外部队周围是否存在克制的敌军,如果是,打他
  # 6. 部队周围是否存在打得过的地,如果是,打他
  # 7. 主城内,是否存在闲置队列,如果是,随机一个建筑进行升级
  # 8. 装死15分钟
  # 9. 什么也不做
  # -----------------
  def loop(%AvatarDef{conn: conn} = player) do
    cond do
      # city_warnning(player) ->
      #   {:ok, player}

      # troop_warnning(player) ->
      #   {:ok, player}

      true ->
        # 随机执行其一
        rand = Enum.random(1..100)

        cond do
          rand <= 10 ->
            troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.random()

            case Avatar.analyze_verse(player, :forward) do
              [_x, _y] = pos ->
                Client.send_msg(conn, [
                  "troop_hero",
                  "add_hero_hp",
                  [troop_guid, [9999, 9999, 9999]]
                ])

                Client.send_msg(conn, ["op", "forward", [troop_guid, pos]])

              _ ->
                nil
            end

            {:ok, player}

          rand <= 20 ->
            troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.random()

            case Avatar.analyze_verse(player, :attack) do
              [_x, _y] = pos ->
                Client.send_msg(conn, [
                  "troop_hero",
                  "add_hero_hp",
                  [troop_guid, [9999, 9999, 9999]]
                ])

                Client.send_msg(conn, ["op", "attack", [troop_guid, pos, 1, false]])

              _ ->
                nil
            end

            {:ok, player}

          rand <= 30 ->
            troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.random()

            case Avatar.analyze_verse(player, :attack) do
              [_x, _y] = pos ->
                Client.send_msg(conn, [
                  "troop_hero",
                  "add_hero_hp",
                  [troop_guid, [9999, 9999, 9999]]
                ])

                Client.send_msg(conn, ["op", "attack", [troop_guid, pos, 1, true]])

              _ ->
                nil
            end

            {:ok, player}

          rand <= 70 ->
            msg = Enum.random(["test", "hah", "hola", "你好~"])
            Client.send_msg(conn, ["chat:send", 1, 1, msg, "{}"])
            {:ok, player}

          true ->
            Client.send_msg(conn, ["gacha:gacha", 1, 5])
            {:ok, player}
        end
    end
  end

  def city_warnning(_player) do
    false
  end

  def troop_warnning(_player) do
    false
  end
end
