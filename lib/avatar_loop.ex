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
  def loop(player) do
    IO.puts("do_loop: player: #{player.account}")
    Avatar.Ets.insert(player.account, self())

    cond do
      # city_warnning(player) ->
      #   {:ok, player}

      # troop_warnning(player) ->
      #   {:ok, player}

      true ->
        # 随机执行其一
        rand = Enum.random(1..100)

        cond do
          # rand <= 75 ->
          #   troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.min()
          #   pos = Avatar.analyze_verse(player, :forward)
          #   Client.send_msg(player.conn, ["op", "forward", [troop_guid, pos]])
          #   IO.puts("forward forward forward forward forward}")
          #   IO.puts("troop_guid: #{inspect(troop_guid)}}")
          #   IO.puts("pos: #{inspect(pos)}}")
          #   {:ok, player}

          # rand <= 95 ->
          #   troop_guid = player |> Map.get(:troops, %{}) |> Map.keys() |> Enum.min()
          #   pos = Avatar.analyze_verse(player, :attack)
          #   Client.send_msg(player.conn, ["op", "attack", [troop_guid, pos]])
          #   IO.puts("atk atk atk atk atk}")
          #   IO.puts("troop_guid: #{inspect(troop_guid)}}")
          #   IO.puts("pos: #{inspect(pos)}}")
          #   {:ok, player}

          rand <= 100 ->
            {:ok, player}
            # {:sleep, 15}
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
