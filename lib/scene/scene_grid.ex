defmodule SceneGrid do

  require Logger

  ## tile
  @tile_width 0.25
  @tile_height 0.25

  ## 掉落格子间距
  @drop_gap 1.2

  ## 视野，小格子的个数
  @vision 50
  @big_vision 30000
  ## 四叉树视野
  @tree_vision 20

  def get_vision() do
    %{instance_id: instance_id} = SceneData.get_scene_id()
    if instance_id > 0 do
      @big_vision
    else
      @vision
    end
  end

  def get_tree_vision() do
    %{instance_id: instance_id} = SceneData.get_scene_id()
    if instance_id > 0 do
      @big_vision
    else
      @tree_vision
    end
  end

  ## 传入格子坐标
  def get_9_slice(x, y) do
    vision = get_vision()
    x1 = trunc(x / vision) * vision
    y1 = trunc(y / vision) * vision
    {x1 - vision, y1 - vision, x1 + vision * 2, y1 + vision * 2}
  end

  def is_pos_in_slice(motion, {x1, y1, x2, y2}) do
    {{x, y}, _} = Motion.peek motion
    is_pos_in_slice(x, y, {x1, y1, x2, y2})
  end

  def is_pix_pos_in_slice(x, y, {x1, y1, x2, y2}) do
    %{x: gridx, y: gridy} = pix_to_grid(x, y)
    is_pos_in_slice(gridx, gridy, {x1, y1, x2, y2})
  end

  ## 传入格子坐标
  def is_pos_in_slice(x, y, {x1, y1, x2, y2}) do
    (x >= x1) && (x < x2) && (y >= y1) && (y < y2)
  end

  def is_same_slice(motion1, motion2) do
    {{x1, y1}, _} = Motion.peek(motion1)
    {{x2, y2}, _} = Motion.peek(motion2)

    %{x: x1_grid, y: y1_grid} = pix_to_grid(x1, y1)
    %{x: x2_grid, y: y2_grid} = pix_to_grid(x2, y2)
    is_same_slice(x1_grid, y1_grid, x2_grid, y2_grid)
  end

  def is_same_slice(x1, y1, x2, y2) do
    vision = get_vision()
    x3 = trunc(x1 / vision)
    x4 = trunc(x2 / vision)
    y3 = trunc(y1 / vision)
    y4 = trunc(y2 / vision)
    (x3 == x4) && (y3 == y4)
  end

  def pix_to_grid(x, y) do
    %{x: trunc(x / @tile_width), y: trunc(y / @tile_height)}
  end

  def grid_to_pix(x, y) do
    %{x: x * @tile_width + @tile_width / 2, y: y * @tile_height + @tile_height / 2}
  end

  def drop_pix_to_grid(x, y) do
    %{x: trunc(x / @drop_gap), y: trunc(y / @drop_gap)}
  end

  def drop_grid_to_pix(x, y) do
    %{x: x * @drop_gap + @drop_gap / 2, y: y * @drop_gap + @drop_gap / 2}
  end


end
