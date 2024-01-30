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
  def loop(%AvatarDef{conn: conn, system_mails: system_mails} = player) do
    cond do
      # city_warnning(player) ->
      #   {:ok, player}

      # troop_warnning(player) ->
      #   {:ok, player}

      true ->
        # 随机执行其一

        weight = %{
          forward: 10,
          attack: 100,
          attack_back: 10,
          chat: 40,
          gacha: 30,
          mail: 10
        }

        index = Enum.random(1..Enum.sum(Map.values(weight)))

        {result, _} =
          Enum.reduce_while(weight, {nil, index}, fn
            {key, this_weight}, {_, index_acc} ->
              if index_acc - this_weight > 0 do
                {:cont, {nil, index_acc - this_weight}}
              else
                {:halt, {key, 0}}
              end

            _, acc ->
              {:cont, acc}
          end)

        cond do
          result == :forward ->
            troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.random()

            case Avatar.analyze_verse(player, :forward) do
              [_x, _y] = pos ->
                Client.send_msg(conn, ["troop_hero:add_hero_hp", troop_guid, [9999, 9999, 9999]])
                Process.sleep(1000)
                Client.send_msg(conn, ["op", "forward", [troop_guid, pos]])

              _ ->
                nil
            end

            {:ok, player}

          result == :attack ->
            troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.random()

            case Avatar.analyze_verse(player, :attack) do
              [_x, _y] = pos ->
                Client.send_msg(conn, ["troop_hero:add_hero_hp", troop_guid, [9999, 9999, 9999]])
                Process.sleep(1000)
                Client.send_msg(conn, ["op", "attack", [troop_guid, pos, 1, false]])

              _ ->
                nil
            end

            {:ok, player}

          result == :attack_back ->
            troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.random()

            case Avatar.analyze_verse(player, :attack) do
              [_x, _y] = pos ->
                Client.send_msg(conn, ["troop_hero:add_hero_hp", troop_guid, [9999, 9999, 9999]])
                Process.sleep(1000)
                Client.send_msg(conn, ["op", "attack", [troop_guid, pos, 1, true]])

              _ ->
                nil
            end

            {:ok, player}

          result == :chat ->
            msg = Enum.random(["test", "hah", "hola", "你好~"])
            Client.send_msg(conn, ["chat:send", 1, 1, msg, "{}"])
            {:ok, player}

          result == :gacha ->
            Client.send_msg(conn, ["gacha:gacha", 1, 5, 1])
            Process.sleep(1000)
            Client.send_msg(conn, ["gacha:gacha", 1, 5, 1])
            Process.sleep(1000)
            Client.send_msg(conn, ["gacha:gacha", 1, 5, 1])
            {:ok, player}

          result == :mail ->
            max_mail_id = (system_mails != %{} && system_mails |> Map.keys() |> Enum.max()) || 0
            Client.send_msg(conn, ["mail:get_attachment", "system", max_mail_id])
            {:ok, player}

          true ->
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
