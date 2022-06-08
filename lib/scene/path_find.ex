defmodule PathFind do
  require Logger

  ## 使用A星寻路
  # 1、待查列表
  # 2、检查周边节点
  # 3、已经检查过的，添加关闭列表
  # 4、启发函数，计算cost f = g + h，暂时用距离计算h值
  # 5、性能有待测试

  ## TODO, 可使用jump point search 算法，性能快很多倍

  @g_normal 1
  @g_corner 1.4

  ## 格子大小
  ## todo,这里应该支持不同场景不同格子大小
  @grid_width 0.8
  @grid_height 0.8

  ## todo, 需要计算直线位移的情况
  def search({fx, fy}, {tx, ty}, map_id, _is_target_moving) do
    %{fileName: file_name} = SceneConfig.get(map_id)
    mod = ("Elixir.Map" <> file_name) |> String.to_existing_atom()

    if can_walk_pix(tx, ty, mod) do
      [rows, cols] = mod.size
      h = euclidian({fx, fy}, {tx, ty})
      id = fy * cols + fx
      {start_grid_x, start_grid_y} = meter_to_grid(fx, fy)
      {end_grid_x, end_grid_y} = meter_to_grid(tx, ty)

      if start_grid_x == end_grid_x && start_grid_y == end_grid_y do
        [{tx, ty}]
      else
        start_node = %{id: id, x: start_grid_x, y: start_grid_y, f: h, g: 0, h: h}
        end_node = %{x: end_grid_x, y: end_grid_y}

        if can_walk_direct({start_grid_x, start_grid_y}, {end_grid_x, end_grid_y}, mod) do
          [{tx, ty}]
        else
          search_full(start_node, end_node, rows, cols, mod, tx, ty)
        end
      end
    else
      {:fail}
    end
  end

  ## 是否能直接走直线
  ## 使用dda 算法判定
  def can_walk_direct({x1, y1}, {x2, y2}, mod) do
    dx = x2 - x1
    dy = y2 - y1
    abs_x = abs(dx)
    abs_y = abs(dy)
    step = if abs_x > abs_y, do: abs_x, else: abs_y
    dx = dx / step
    dy = dy / step
    can_walk_direct_1(x1, y1, dx, dy, step, 1, mod)
  end

  defp can_walk_direct_1(x, y, _dx, _dy, step, i, mod) when i > step do
    can_walk({round(x), round(y)}, mod)
  end

  defp can_walk_direct_1(x, y, dx, dy, step, i, mod) do
    if can_walk({round(x), round(y)}, mod) do
      x = x + dx
      y = y + dy
      i = i + 1
      can_walk_direct_1(x, y, dx, dy, step, i, mod)
    else
      Logger.debug("can not walk direct, x is #{x}, y is #{y}")
      false
    end
  end

  defp search_full(start_node, end_node, rows, cols, mod, tx, ty) do
    case do_search(start_node, end_node, rows, cols, %{}, %{}, mod) do
      {:ok, last_node} ->
        path = make_path(start_node, last_node, []) |> flatten()

        meter_fun = fn {gx, gy} ->
          if gx == end_node.x && gy == end_node.y do
            {tx, ty}
          else
            grid_to_meter(gx, gy)
          end
        end

        Enum.map(path, meter_fun)

      _re ->
        {:fail}
    end
  end

  def search_near_one(start_node, end_node, rows, cols, mod) do
    neighbors = get_neighbor({start_node.x, start_node.y}, rows, cols)

    fun = fn {test_x, test_y}, list ->
      #      if can_walk({test_x, test_y}, mod) && can_walk({test_x, start_node.y}, mod) && can_walk({start_node.x, test_y}, mod) do   ## 拐角平滑处理
      ## 拐角平滑处理
      if can_walk({test_x, test_y}, mod) do
        cost =
          if test_x == start_node.x || test_y == start_node.y do
            @g_normal
          else
            @g_corner
          end

        g = cost
        h = euclidian({test_x, test_y}, {end_node.x, end_node.y})
        f = g + h

        t_node = %{x: test_x, y: test_y, f: f}
        [t_node | list]
      else
        list
      end
    end

    results = Enum.reduce(neighbors, [], fun)

    if results != [] do
      re_node = Enum.min_by(results, & &1.f)
      [grid_to_meter(re_node.x, re_node.y)]
    else
      {:fail}
    end
  end

  def search_with_grid({fx, fy}, {tx, ty}, map_id) do
    module = "map_" <> Integer.to_string(map_id)
    mod = ("Elixir." <> (module |> Macro.camelize())) |> String.to_existing_atom()
    [rows, cols] = mod.size
    h = euclidian({fx, fy}, {tx, ty})
    id = fy * cols + fx
    start_node = %{id: id, x: fx, y: fy, f: h, g: 0, h: h}
    end_node = %{x: tx, y: ty}

    case do_search(start_node, end_node, rows, cols, %{}, %{}, mod) do
      {:ok, last_node} ->
        path = make_path(start_node, last_node, [])
        Logger.debug("finally path is #{inspect(path)}")

      _ ->
        {:fail}
    end
  end

  def do_search(%{x: x, y: y} = last_node, %{x: x, y: y}, _rows, _cols, _open, _close, _mod) do
    {:ok, last_node}
  end

  ## src 为当前要检查的点
  def do_search(node, des, rows, cols, open_list, close_list, mod) do
    neighbors = get_neighbor({node.x, node.y}, rows, cols)

    fun = fn {test_x, test_y}, {opens, closes} ->
      if can_walk({test_x, test_y}, mod) && not_same_node?({test_x, test_y}, node) do
        #      && can_walk({test_x, node.y}, mod) && can_walk({node.x, test_y}, mod) do   ## 拐角平滑处理
        cost =
          if test_x == node.x || test_y == node.y do
            @g_normal
          else
            @g_corner
          end

        g = node.g + cost
        h = euclidian({test_x, test_y}, {des.x, des.y})
        f = g + h

        id = test_y * cols + test_x
        t_node = %{id: id, x: test_x, y: test_y, f: f, g: g, h: h, parent: node}

        if Map.has_key?(opens, id) || Map.has_key?(closes, id) do
          {replace(opens, id, t_node, f), replace(closes, id, t_node, f)}
        else
          {Map.put(opens, id, t_node), closes}
        end
      else
        {opens, closes}
      end
    end

    {opens_1, closes_1} = Enum.reduce(neighbors, {open_list, close_list}, fun)

    if Enum.count(opens_1) > 0 do
      closes_2 = Map.put(closes_1, node.id, node)
      {_, next_node} = Enum.min_by(opens_1, fn {_id, open_node} -> open_node.f end)
      opens_2 = Map.drop(opens_1, [next_node.id])

      #      Logger.debug "next node is #{inspect Map.drop(next_node, [:parent])}, node is #{inspect Map.drop(node, [:parent])}"
      do_search(next_node, des, rows, cols, opens_2, closes_2, mod)
    else
      #     Logger.debug "can not find a path, node is #{inspect Map.drop(node, [:parent])}"
      {:fail}
    end
  end

  defp replace(map, id, node, f) do
    if Map.has_key?(map, id) do
      if Map.get(map, id).f > f do
        Map.put(map, id, node)
      else
        map
      end
    else
      map
    end
  end

  defp not_same_node?({x, y}, node) do
    !(x == node.x && y == node.y)
  end

  def get_neighbor({x, y}, rows, cols) do
    list = [
      {x - 1, y - 1},
      {x, y - 1},
      {x + 1, y - 1},
      {x - 1, y},
      {x + 1, y},
      {x - 1, y + 1},
      {x, y + 1},
      {x + 1, y + 1}
    ]

    Enum.filter(list, fn {xx, yy} -> xx <= cols && yy <= rows end)
  end

  def can_walk({x, y}, mod) do
    [max_y, max_x] = mod.size

    if(x < max_x - 1 && y < max_y - 1 && x > 0 && y > 0) do
      data = mod.data
      :erlang.element(x + 1, :erlang.element(y + 1, data)) == 0
    else
      false
    end
  end

  ## 供外部调用, x, y为米坐标
  def can_walk_pix(x, y) do
    %{id: scene_id} = SceneData.get_scene_id()
    %{fileName: file_name} = SceneConfig.get(scene_id)
    mod = ("Elixir.Map" <> file_name) |> String.to_existing_atom()
    {gx, gy} = meter_to_grid(x, y)
    can_walk({gx, gy}, mod)
  end

  defp can_walk_pix(x, y, mod) do
    meter_to_grid(x, y)
    |> can_walk(mod)
  end

  # defp manhattan({fx, fy}, {tx, ty}) do
  #   abs(fx - tx) * @g_normal + abs(fy + ty) * @g_normal
  # end

  defp euclidian({fx, fy}, {tx, ty}) do
    dx = tx - fx
    dy = ty - fy
    dx * dx + dy * dy
  end

  defp make_path(%{x: x, y: y}, %{x: x, y: y}, path) do
    path
  end

  ## 这里返回像素点
  defp make_path(start_node, last_node, path) do
    make_path(start_node, last_node.parent, [{last_node.x, last_node.y} | path])
  end

  def meter_to_grid(x, y) do
    {trunc(x / @grid_width), trunc(y / @grid_height)}
  end

  def grid_to_meter(x, y) do
    {x * @grid_width + @grid_width / 2, y * @grid_height + @grid_height / 2}
  end

  def flatten([]), do: []
  def flatten([_] = path), do: path
  def flatten([_, _] = path), do: path

  def flatten(path) do
    Enum.reduce(path, [], fn
      node, [] ->
        [node]

      node, [last] ->
        [node, last]

      {_x, y} = node, [{_x1, y} | [{_x2, y} | _] = remains] ->
        [node | remains]

      {x, y} = node, [{x1, y1} | [{x2, y2} | _] = remains] = current ->
        cond do
          y == y1 or y1 == y2 ->
            [node | current]

          abs((x1 - x2) / (y1 - y2) - (x - x1) / (y - y1)) < 0.01 ->
            [node | remains]

          true ->
            [node | current]
        end
    end)
    |> Enum.reverse()
  end
end
