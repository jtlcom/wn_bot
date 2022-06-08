defmodule AvatarLoop do
  require Logger
  alias Avatar.Player
  @normal_skills [410_101_000]

  @born_state 0
  @guard_state 1
  @patrol_state 2
  @move_state 3
  @fight_state 4
  @dead_state 5
  @quiz_state 6
  @pickup_state 7
  @do_nothing 8
  @fighting 9
  @collect 10
  @collecting 11

  @in_circle_use_skill 3
  @use_skill_delay 100
  @range 20.5
  @collect_rang 100
  @inffinity_distance 999999

  @pk_mode_all 0
  ## 无法攻击队友和同阵营
  def pk_mode_all_type, do: @pk_mode_all
  @pk_mode_peace 1
  def pk_mode_peace_type, do: @pk_mode_peace
  @pk_mode_group 2
  ## 军团
  def pk_mode_group_type, do: @pk_mode_group
  @pk_mode_team 3
  def pk_mode_team_type, do: @pk_mode_team
  @pk_mode_camp 4
  def pk_mode_camp_type, do: @pk_mode_camp
  @pk_mode_god 5
  ## 上帝模式可以攻击队友和同一个阵营
  def pk_mode_god_type, do: @pk_mode_god

  def loop(player) do
    now_time = System.system_time(:millisecond)

    if is_active(player, now_time) do
      {:ok, do_loop(player, now_time)}
    else
      player
    end
  end

  defp do_loop(player, now_time) do
    # IO.inspect player.id
    # (player.id == 335561097262) && IO.inspect(player.state)
    # Logger.info "scene_id is: #{player.scene_id}, state is: #{player.state}, all_drop is : #{inspect SceneData.get_all_drop()}"
    player1 =
      case player.state do
        @born_state ->
          on_born(player)

        @guard_state ->
          on_guard(player, now_time)

        @patrol_state ->
          on_patrol(player, now_time)

        @move_state ->
          on_move(player)

        @fight_state ->
          on_fight(player, now_time)

        @pickup_state ->
          on_pickup(player)

        @quiz_state ->
          on_quiz(player)

        @dead_state ->
          on_dead(player, now_time)

        @do_nothing ->
          do_nothing(player)

        @fighting ->
          on_fighting(player, now_time)

        @collect ->
          on_collect(player, now_time)

        @collecting ->
          on_collecting(player, now_time)

        what ->
          Logger.debug("this state is what???? #{inspect(what)}")
          player
      end

    # Logger.warn("player state is #{inspect(player1.state)}")

    player1
  end

  defp on_born(player) do
    %Player{player | state: @guard_state}
  end

  defp on_guard(player, _now_time) do
    %Player{player | state: @patrol_state}
  end

  defp on_quiz(player) do
    player
  end

  def do_nothing(player) do
    player
  end

  defp on_patrol(player, _now_time) do
    # %Player{player | state: @guard_state}
    cond do
      player.scene_id != 1010 && player.scene_id in SceneConfig.get_all() ->
        # do find aimed entity
        case find_near_drop(player) do
          {:ok, %{id: d_id, pos: %{x: d_x, y: d_y}} = _drop} ->
            {{old_x, old_y}, _} = Motion.peek(player.motion)

            case AnimalBehavior.find_path(old_x, old_y, d_x, d_y, player.scene_id) do
              {:ok, point, path} ->
                player1 = %Player{
                  player
                  | state: @move_state,
                    move_path: path,
                    next_state: @pickup_state,
                    aimed_drop_id: d_id
                }

                move_to_point(player1, {old_x, old_y}, point)

              _ ->
                next_find(player)
            end

          _ ->
            next_find(player)
        end

      true ->
        # Logger.info "on patrol...., scene_id : #{player.scene_id}"
        random_move(player)
        # ballast_use_skill(player)
    end
  end

  def next_find(player) do
    case find_near_collect(player) do
      {:ok, %{id: c_id, pos: {c_x, c_y}} = _drop} ->
        {{old_x, old_y}, _} = Motion.peek(player.motion)
        case AnimalBehavior.find_path(old_x, old_y, c_x, c_y, player.scene_id) do
          {:ok, point, path} ->
            player1 = %Player{
              player
              | state: @move_state,
                move_path: path,
                next_state: @collect,
                collect_id: c_id
            }
            move_to_point(player1, {old_x, old_y}, point)
          _ ->
            %Player{player | state: @collect, collect_id: c_id}
        end
      _ ->
        find_monster(player)
    end
  end

  def find_near_drop(player) do
    {{p_x, p_y}, _} = Motion.peek(player.motion)

    fun = fn %{pos: %{x: x, y: y}} = drop, acc ->
      {x_dis, y_dis} = {p_x - x, p_y - y}
      dis_2_time = x_dis * x_dis + y_dis * y_dis

      case acc do
        %{dis_2_time: dis_old} ->
          if dis_2_time < dis_old do
            %{drop: drop, x: x, y: y, dis_2_time: dis_2_time}
          else
            acc
          end

        _ ->
          if dis_2_time < @range * @range do
            %{drop: drop, x: x, y: y, dis_2_time: dis_2_time}
          else
            acc
          end
      end
    end

    case Enum.reduce(SceneData.get_all_drop(), %{}, fun) do 
      %{drop: near_drop} ->
        {:ok, near_drop}

      _ ->
        :skip
    end
  end

  @cross_server_map [423001, 423002]
  def find_near_collect(player) do
    cond do
      player.scene_id in @cross_server_map ->
        find_near_collect_1(player)
      true ->
        :skip
    end
  end

  defp find_near_collect_1(player) do
    # IO.inspect SceneData.get_all_collect_entities()
    {{p_x, p_y}, _} = Motion.peek(player.motion)

    fun = fn %{pos: {x, y}} = collect, acc ->
      {x_dis, y_dis} = {p_x - x, p_y - y}
      dis_2_time = x_dis * x_dis + y_dis * y_dis

      case acc do
        %{dis_2_time: dis_old} ->
          if dis_2_time < dis_old do
            %{collect: collect, x: x, y: y, dis_2_time: dis_2_time}
          else
            acc
          end

        _ ->
          if dis_2_time < @collect_rang * @collect_rang do
            %{collect: collect, x: x, y: y, dis_2_time: dis_2_time}
          else
            acc
          end
      end
    end

    case Enum.reduce(SceneData.get_all_collect_entities(), %{}, fun) do 
      %{collect: near_collect} ->
        {:ok, near_collect}

      _ ->
        :skip
    end
  end

  def find_monster(player) do
    # all_monsters = 
    # Logger.warn("find monster, all monster is #{inspect(all_monsters)}")
    # "此处应该寻找最短路径长度的怪的坐标,目前用随机的怪的坐标"
    # with true <- all_monsters != [],
    #      %{id: sn, pos: {aim_x, aim_y}, hp: hp} <-
    #        ,
    entity_aim = case Application.get_env(:pressure_test, :path_find_strategy) do
      # 就近寻找
      type when type in [:near, :only_player] ->
        find_near_aim(player, player.camp, player.pk_mode, type)

      :not_fight ->
        nil

      _ ->
        can_kill_monsters = find_can_kill_monsters(player.id, player.camp, player.pk_mode)
        can_kill_monsters != [] && SceneData.get_entity_by_id(Enum.random(can_kill_monsters)) || nil
    end
    with %{id: sn, pos: {aim_x, aim_y}, hp: hp} <- entity_aim,
         true <- hp > 0 do
      rand_offset = (-10..10 |> Enum.random()) * 0.15
      {aim_x, aim_y} = {aim_x + rand_offset, aim_y + rand_offset}
      {{old_x, old_y}, _} = Motion.peek(player.motion)

      case AnimalBehavior.find_path(old_x, old_y, aim_x, aim_y, player.scene_id) do
        {:ok, point, path} ->
          player1 = %Player{
            player
            | state: @move_state,
              move_path: path,
              next_state: @fight_state,
              aimed_entity: sn
          }

          # move_to_point(player1, {old_x, old_y}, {32,10})
          move_to_point(player1, {old_x, old_y}, point)

        _ ->
          # Logger.info "aimed_pos: #{inspect {aim_x, aim_y}}, player_pos: #{inspect {old_x, old_y}}, find_path map: #{player.scene_id}"
          random_move(player)
          # ballast_use_skill(player)
      end
    else
      _ ->
        # if(:rand.uniform(2) > 1) do
        #   ballast_use_skill(player)
        # else
          random_move(player)
        # end
    end
  end

  @collect_delay 1500
  def on_collect(%{collect_id: collect_id} = player, _now_time) do
    IO.inspect "on_collect #{collect_id}"
    Client.send_msg(player.conn, ["gm:reset_acts"])
    Client.send_msg(player.conn, ["wild_boss_zone:start_collect", collect_id])
    Upload.trans_info("wild_boss_zone:start_collect", 10, Utils.timestamp())
    %Player{
      player
      | state: @collecting,
        next_state: @guard_state,
        collect_complete: Utils.timestamp(:ms) + @collect_delay
    }
  end

  def on_collecting(%{collect_id: collect_id} = player, now_time) do
    if now_time > player.collect_complete do
      IO.inspect "collect over"
      Client.send_msg(player.conn, ["wild_boss_zone:end_collect", collect_id])
      # SceneData.delete_entity(collect_id)
      %{player | state: player.next_state}
    else
      player
    end
  end
  
  def ballast_use_skill(player) do
    if player.scene_id != 1010 do
      skill_id =
        case player.gender do
          1 ->
            410_101_000

          2 ->
            410_201_000

          3 ->
            410_301_000
        end

      Client.send_msg(player.conn, [
        "skill:cast",
        0,
        skill_id,
        0,
        0,
        0,
        0,
        0,
        0,
        0
      ])

      # Process.put("skill:cast", Utils.timestamp(:ms))

      Upload.trans_info("skill:cast", :rand.uniform(50), Utils.timestamp())

      %Player{
        player
        | state: @fighting,
          next_state: @guard_state,
          next_skill_time: System.system_time(:millisecond) + 150
      }
    else
      random_move(player)
    end
  end

  defp find_can_kill_monsters(_player_id, a_camp, pk_mode) do
    # Logger.info "pk_mode is : #{pk_mode}, camp is : #{a_camp}"
    case pk_mode do
      _ ->
        SceneData.get_all_monster()
        |> Enum.filter(fn sn ->
          %{hp: hp, master_id: master_id, camp: camp} = SceneData.get_entity_by_id(sn)
          hp > 0 && master_id == 0 && camp != a_camp
        end)

        # |> #IO.inspect
    end
  end

  defp find_near_aim(player, a_camp, _pk_mode, type) do
    {strategy_aims, fun} = 
    case type do
      :near ->
       {SceneData.get_all_monster() ++ SceneData.get_all_player(), fn {a_camp, camp, master_id} -> (master_id <= 0) && (camp != a_camp) end}
      :only_player ->
        {SceneData.get_all_player(), fn {a_camp, camp, _master_id} -> a_camp != camp end}
      _ ->
        {SceneData.get_all_monster() ++ SceneData.get_all_player(), fn {a_camp, camp, master_id} -> (master_id <= 0) && (camp != a_camp) end}
    end
    strategy_aims
    |> Enum.reduce({@inffinity_distance, nil}, fn sn, {tmp_dis, _} = acc ->
      case SceneData.get_entity_by_id(sn) do
        %{hp: hp, master_id: master_id, camp: camp, pos: {e_x, e_y}} = entity when hp > 0 ->
          if fun.({a_camp, camp, master_id}) do
            {{old_x, old_y}, _} = Motion.peek(player.motion)
            dis = dis_2_time(old_x, old_y, e_x, e_y)
            if dis < tmp_dis do
              {dis, entity}
            else
              acc
            end
          else
            acc
          end
        _ ->
          acc
      end
    end)
    |> elem(1)
  end

  def random_move(player) do
    {{old_x, old_y}, _} = Motion.peek(player.motion)
    new_x = old_x + Enum.random(-50..50) / 10
    new_y = old_y + Enum.random(-50..50) / 10

    case AnimalBehavior.find_path(old_x, old_y, new_x, new_y, player.scene_id) do
      {:ok, point, path} ->
        player1 = %Player{player | state: @move_state, move_path: path, next_state: @guard_state}
        move_to_point(player1, {old_x, old_y}, point)

      _ ->
        %Player{player | state: @guard_state}
    end

    # %Player{player | state: @guard_state}
  end

  defp on_move(player) do
    case player.move_path do
      [] ->
        %Player{player | state: player.next_state}

      [{x, y} | next_path] ->
        {{now_x, now_y}, _} = Motion.peek(player.motion)

        if is_arrive(now_x, now_y, x, y) do
          case next_path do
            [next_point | _] ->
              %Player{player | move_path: next_path}
              |> move_to_point({now_x, now_y}, next_point)

            _ ->
              %Player{player | move_path: next_path, state: player.next_state}
          end
        else
          player
        end
    end
  end

  def on_pickup(player) do
    drop_id = player.aimed_drop_id
    Client.send_msg(player.conn, ["skill:pickup_drop", drop_id])
    SceneData.del_drop(drop_id)
    %Player{player | state: @guard_state}
    # ballast_use_skill(player)
  end

  # ["skill:cast",  defender_id, spell_id, dir_x, dir_y, target_x, target_y, move_x, move_y]
  # 参数说明
  # defender_id: 被攻击者id
  # spell_id: 技能id
  # dir_x: 方向x
  # dir_y: 方向z
  # target_x: 攻击目标点x
  # target_z: 攻击目标点z

  defp on_fight(player, now_time) do
    # if rem(player.id, 2) == 0 do
    #   random_move(player)
    # else
      # Logger.warn("1111")
      on_fight_1(player, now_time)
    # end
  end

  @reject_spells [410114000]
  defp on_fight_1(player, _now_time) do
    with true <- player.points.hp > 0,
         %{pos: {a_x, a_y} = _aimed_pos, hp: hp, master_id: master_id} <-
           SceneData.get_monster_by_id(player.aimed_entity),
         true <- hp > 0,
         true <- master_id != player.id,
         {{p_x, p_y} = _p_pos, _} = Motion.peek(player.motion),
         {dx, dy} = {a_x - p_x, a_y - p_y},
         distance = dx * dx + dy * dy,
         max_circle = @in_circle_use_skill * @in_circle_use_skill,
         true <- distance < max_circle do
      # "判断是否在范围内及方向，范围内释放技能"
      # "判断技能冷却与否"
      can_used_spell_ids =
        player.spells
        |> Enum.reduce([], fn {spell_id, %{last_use_time: last_use_time}}, acc ->
          cd = Map.get(SpellConfig.by_spell(spell_id, 1), :cd, 0)

          can_use? =
            (System.system_time(:millisecond) > last_use_time + cd * 1000 + @use_skill_delay) && (spell_id not in @reject_spells)

          (can_use? && acc ++ [spell_id]) || acc
        end)

      # #IO.inspect can_used_spell_ids
      with true <- can_used_spell_ids != [],
           use_spell_id <- Enum.random(can_used_spell_ids),
           tmp_spell <- player.spells[use_spell_id] do
        # Logger.warn("use skill")
        # start_time = Utils.timestamp(:ms)

        Client.send_msg(player.conn, [
          "skill:cast",
          player.aimed_entity,
          use_spell_id,
          dx,
          dy,
          a_x,
          a_y,
          0,
          0,
          0
        ])

        # Process.put("skill:cast", Utils.timestamp())

        # end_time = Utils.timestamp(:ms)
        Upload.trans_info("skill:cast", Enum.random(50..150), Utils.timestamp())

        next_skill_time_delay =
          if use_spell_id in @normal_skills do
            150
          else
            1100
          end

        new_spells =
          player.spells
          |> Map.put(
            use_spell_id,
            tmp_spell |> Map.put(:last_use_time, System.system_time(:millisecond))
          )

        if SceneData.get_monster_by_id(player.aimed_entity)[:hp] > 0 do
          %Player{
            player
            | spells: new_spells,
              state: @fighting,
              next_state: @fight_state,
              next_skill_time: System.system_time(:millisecond) + next_skill_time_delay
          }
        else
          random_move(player)
          # ballast_use_skill(player)
        end
      else
        _ ->
          ballast_use_skill(player)
          # %Player{player | state: @guard_state}
      end
    else
      _ ->
        ballast_use_skill(player)
        # %Player{player | state: @guard_state}
    end
  end

  defp on_fighting(player, now_time) do
    if now_time > player.next_skill_time do
      %{player | state: player.next_state}
    else
      player
    end
  end

  defp on_dead(player, _now_time) do
    # SceneData.del_all_entity()
    Client.send_msg(player.conn, ["revive", 0])
    player
  end

  defp is_active(_player, now_time) do
    if now_time >= get_work_time() do
      true
    else
      false
    end
  end

  def get_work_time() do
    :erlang.get({:avatar})
  end

  def set_work_time(time) do
    :erlang.put({:avatar}, time)
  end

  def move_to_point(player, {old_x, old_y}, {x, y}) do
    AnimalBehavior.move_to_point(player, {old_x, old_y}, {x, y})
  end

  defp is_arrive(now_x, now_y, tx, ty) do
    dis_2_time(now_x, now_y, tx, ty) < 0.1
  end

  def dis_2_time(x1, y1, x2, y2) do
    x_dis = x2 - x1
    y_dis = y2 - y1
    x_dis * x_dis + y_dis * y_dis
  end
end
