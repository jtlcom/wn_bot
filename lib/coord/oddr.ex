defmodule Oddr do
  def direction_index(center, target) do
    Cube.direction_index(CubeDef.new(center), CubeDef.new(target))
  end

  def direct?(center, target) do
    Cube.direct?(CubeDef.new(center), CubeDef.new(target))
  end

  def direct(pos, direction, distance) do
    Cube.direct(CubeDef.new(pos), direction, distance, &CubeDef.to_oddr/1)
  end

  def neighbor(pos, direction) do
    Cube.neighbor(CubeDef.new(pos), direction, &CubeDef.to_oddr/1)
  end

  def neighbors(center) do
    Cube.neighbors(CubeDef.new(center), &CubeDef.to_oddr/1)
  end

  # hint: 机器人这边的坐标不是{} 是[]
  def neighbors([[_ | _] | _] = pos_list, range, with_center?) do
    Cube.neighbors(Enum.map(pos_list, &CubeDef.new/1), range, with_center?, &CubeDef.to_oddr/1)
  end

  def neighbors(center, range, with_center?) do
    Cube.neighbors(CubeDef.new(center), range, with_center?, &CubeDef.to_oddr/1)
  end

  def distance(a, b) do
    Cube.distance(CubeDef.new(a), CubeDef.new(b))
  end

  def linedraw(a, b) do
    Cube.linedraw(CubeDef.new(a), CubeDef.new(b), &CubeDef.to_oddr/1)
  end

  def ring(center, radius) do
    Cube.ring(CubeDef.new(center), radius, &CubeDef.to_oddr/1)
  end

  def new(pos, {q, r, s}) do
    center = CubeDef.new(pos)
    CubeDef.to_oddr(CubeDef.new(center.q + q, center.r + r, center.s + s))
  end
end
