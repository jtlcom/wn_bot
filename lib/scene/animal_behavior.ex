defmodule AnimalBehavior do

  require Logger
  alias Avatar.Player

  def find_path(fx, fy, tx, ty, scene_id) do
    case PathFind.search({fx, fy}, {tx, ty}, scene_id, false) do
      [point | _] = path ->
        {:ok, point, path}
      _re ->
        # Logger.debug "re is #{inspect re}, scene_id is #{scene_id}, fx is #{fx}, fy is #{fy},
        # tx is #{tx}, ty is #{ty}"
        {:fail}
    end
  end

  def get_spell(spells) do
    now_time = System.system_time(:millisecond)
    fun = fn({id, ss}, {r_id, r_ss, r_time}) ->
      gap = now_time - ss.last_use_time
      %{cd: cd} = SpellConfig.by_spell id, 1
      cd = cd == 0 && 2 || cd

#      Logger.debug "cd is #{inspect cd}, gap is #{gap}"
      left_time = cd * 1000 - gap
      if left_time <= 0 do
        if Map.get(ss, :priority, 0) > Map.get(r_ss, :priority, 0) do
          {id, ss, left_time}
        else
          if left_time < r_time do
            {id, ss, left_time}
          else
            {r_id, r_ss, r_time}
          end
        end
      else
        if left_time < r_time do
          {id, ss, left_time}
        else
          {r_id, r_ss, r_time}
        end
      end
    end

    if Enum.count(spells) > 0 do
      {init_id, init_spell} = Enum.at(spells, 0)
      # init_gap = now_time - init_spell.last_use_time
      %{cd: init_cd} = SpellConfig.by_spell init_id, 1
      init_time = init_cd * 1000
      Enum.reduce(spells, {init_id, init_spell, init_time}, fun)
    else
      :ok
    end

  end

  ## 获取距离目标前面的点
  def get_front_pos(fx, fy, tx, ty, dis) do
    ux = tx - fx
    uy = ty - fy
    angle = :math.atan2(uy, ux)
    sin_angle = :math.sin(angle)
    cos_angle = :math.cos(angle)
    tx = dis * cos_angle + fx
    ty = dis * sin_angle + fy
    {tx, ty}
  end

  ## 一个坑：可能算出来的坐标等于自己原始坐标
  def get_front_pos(fx, fy, tx, ty, att_dis, offset_angle) do
    ux = tx - fx
    uy = ty - fy
    off_set = (:math.pi / 180) * offset_angle
    angle = :math.atan2(uy, ux) + off_set
    sin_angle = :math.sin(angle)
    cos_angle = :math.cos(angle)
    dis = (point_dis(fx, fy, tx, ty) - att_dis)
    tx1 = (dis * cos_angle + fx) |> trunc
    ty1 = (dis * sin_angle + fy) |> trunc

    if (tx1 == fx) && (ty1 == fy) do
      get_front_pos(fx, fy, tx, ty, att_dis - 1, offset_angle)
    else
      {tx1, ty1}
    end
  end

  def get_forward_pos(fx, fy, tx, ty, dis, offset_angle, trace_dis \\ 3) do
    ux = tx - fx
    uy = ty - fy
    off_set = (:math.pi / 180) * Enum.random((offset_angle * -1)..offset_angle)
    angle = :math.atan2(uy, ux) + off_set
    sin_angle = :math.sin(angle)
    cos_angle = :math.cos(angle)
    dis = point_dis(fx, fy, tx, ty) - dis
    dis = min(dis, trace_dis)
    tx = dis * cos_angle + fx
    ty = dis * sin_angle + fy
    {tx, ty}
  end

  ## b.x = ( a.x - o.x)*cos(angle) - (a.y - o.y)*sin(angle) + o.x
  ## b.y = (a.x - o.x)*sin(angle) + (a.y - o.y)*cos(angle) + o.y
  ## TODO, 此处要考量性能问题 ！！！！！！
  def find_pos_around_target(att_id, target, att_x, att_y) do
    # grid_pos = target.grid_pos
    # att_grid = SceneGrid.pix_to_grid(att_x, att_y)
    all = SceneData.get_all_monster() |> Map.drop([att_id])
    {{tx, ty}, _} = Motion.peek(target.motion)
    offset = 40 + :rand.uniform(40)
    find_pos_around_target_1(all, tx, ty, att_x, att_y, offset)
  end

  def find_pos_around_target_1(_all, _target_x, _target_y, _att_x, _att_y, angle) when angle > 360 do
    :false
  end

  def find_pos_around_target_1(_all, _target_x, _target_y, _att_x, _att_y, angle) when angle < -360 do
    :false
  end

  def find_pos_around_target_1(_all, target_x, target_y, att_x, att_y, angle) do
    sin_angle = :math.sin(angle)
    cos_angle = :math.cos(angle)
    x = (att_x - target_x)*cos_angle - (att_y - target_y)*sin_angle + target_x
    y = (att_x - target_x)*sin_angle + (att_y - target_y)*cos_angle + target_y

    # att_grid = SceneGrid.pix_to_grid(x, y)
    {:move, x, y}
  end

  def point_dis(x1, y1, x2, y2) do
    x_dis = x2 - x1
    y_dis = y2 - y1
    x_dis * x_dis + y_dis * y_dis
    |> :math.sqrt()
  end

  def move_to_point(player, {fx, fy}, {tx, ty}) do
    Client.send_msg(player.conn,["move", fx, fy, tx, ty])
    # Process.put("move", Utils.timestamp(:ms))
    # start_time = Utils.timestamp(:ms)
    speed = Map.get(player.stats, :moveSpeed, 0)
    ts = System.system_time(:millisecond)
    new_motion = {:moving, fx, fy, tx, ty, ts, speed}
    # end_time = Utils.timestamp(:ms)
    Upload.trans_info("move", Enum.random(50..150), Utils.timestamp())
    # IO.inspect "move"
    # (end_time - start_time > 1000) && IO.inspect("move #{end_time - start_time}")
    %Player{player | motion: new_motion}
  end

end
