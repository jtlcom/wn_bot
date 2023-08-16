defmodule Cube do
  # q, r, s
  @direction_vectors [
    # 右0
    CubeDef.new(1, 0, -1),
    # 右上角1
    CubeDef.new(1, -1, 0),
    # 左上角2
    CubeDef.new(0, -1, 1),
    # 左3
    CubeDef.new(-1, 0, 1),
    # 左下角4
    CubeDef.new(-1, 1, 0),
    # 右下角5
    CubeDef.new(0, 1, -1)
  ]

  def direction(direction) do
    Enum.at(@direction_vectors, direction)
  end

  def direction_index(%CubeDef{} = center, %CubeDef{} = target) do
    cond do
      center.r == target.r and target.q > center.q and center.s > target.s and
          abs(target.q - center.q) == abs(center.s - target.s) ->
        0

      center.s == target.s and target.q > center.q and center.r > target.r and
          abs(target.q - center.q) == abs(center.r - target.r) ->
        1

      center.q == target.q and center.r > target.r and target.s > center.s and
          abs(center.r - target.r) == abs(target.s - center.s) ->
        2

      center.r == target.r and center.q > target.q and target.s > center.s and
          abs(center.q - target.q) == abs(target.s - center.s) ->
        3

      center.s == target.s and center.q > target.q and target.r > center.r and
          abs(center.q - target.q) == abs(target.r - center.r) ->
        4

      center.q == target.q and target.r > center.r and center.s > target.s and
          abs(target.r - center.r) == abs(center.s - target.s) ->
        5

      true ->
        -1
    end
  end

  def direction_index(_center, _target), do: -1

  def direct?(%CubeDef{} = center, %CubeDef{} = target) do
    case direction_index(center, target) do
      -1 -> false
      _ -> true
    end
  end

  def direct?(_center, _target), do: false

  def direct(%CubeDef{} = cube, direction, distance, func \\ nil) do
    direct_cube = direction(direction)
    1..distance |> Enum.map(&(CubeDef.add(cube, CubeDef.scale(direct_cube, &1)) |> convert(func)))
  end

  def neighbor(cube, direction, func \\ nil)

  def neighbor(%CubeDef{} = cube, direction, func) do
    CubeDef.add(cube, direction(direction)) |> convert(func)
  end

  def neighbor(_pos, _direction, _func), do: nil

  def neighbors(center, func \\ nil)

  def neighbors(%CubeDef{} = center, func) do
    @direction_vectors |> Enum.map(&CubeDef.add(center, &1)) |> convert(func)
  end

  def neighbors(_center, _func), do: []

  def neighbors(center, range, with_center?, func \\ nil)

  def neighbors([_ | _] = list, range, with_center?, func) do
    list
    |> Enum.flat_map(fn t ->
      neighbors = neighbors(t, range, with_center?)
      (with_center? && neighbors) || neighbors -- list
    end)
    |> Enum.uniq()
    |> convert(func)
  end

  def neighbors(%CubeDef{} = center, range, with_center?, func) do
    Enum.flat_map(-range..range, fn q ->
      Enum.flat_map(max(-range, -q - range)..min(range, -q + range), fn r ->
        s = -q - r
        t = CubeDef.add(center, CubeDef.new(q, r, s))
        (t != center && [t]) || ((with_center? && [t]) || [])
      end)
    end)
    |> convert(func)
  end

  def neighbors(_center, _range, _with_center?, _func), do: []

  def distance(%CubeDef{} = a, %CubeDef{} = b) do
    vec = CubeDef.dec(a, b)
    trunc((abs(vec.q) + abs(vec.r) + abs(vec.s)) / 2)
  end

  def distance(_a, _b), do: nil

  defp lerp_(a, b, t) do
    a + (b - a) * t
  end

  defp lerp(%CubeDef{} = a, %CubeDef{} = b, t) do
    CubeDef.new(lerp_(a.q, b.q, t), lerp_(a.r, b.r, t), lerp_(a.s, b.s, t))
  end

  def round(%CubeDef{} = frac) do
    q = Kernel.round(frac.q)
    r = Kernel.round(frac.r)
    s = Kernel.round(frac.s)
    q_diff = abs(q - frac.q)
    r_diff = abs(r - frac.r)
    s_diff = abs(s - frac.s)

    cond do
      q_diff > r_diff and q_diff > s_diff -> {-r - s, r, s}
      r_diff > s_diff -> {q, -q - s, s}
      true -> {q, r, -q - r}
    end
    |> CubeDef.new()
  end

  def round(_frac), do: nil

  def linedraw(a, b, func \\ nil)

  def linedraw(%CubeDef{} = a, %CubeDef{} = b, func) when a != b do
    n = distance(a, b)

    Enum.map(0..n, fn i ->
      Cube.round(lerp(a, b, 1.0 / n * i))
    end)
    |> convert(func)
  end

  def linedraw(_a, _b, _func), do: []

  def ring(center, radius, func \\ nil)

  def ring(%CubeDef{} = center, radius, func) when radius < 1 do
    [center] |> convert(func)
  end

  def ring(%CubeDef{} = center, radius, func) do
    hex = CubeDef.add(center, CubeDef.scale(Cube.direction(4), radius))

    {_, list} =
      Enum.reduce(0..5, {hex, []}, fn i, acc ->
        Enum.reduce(0..(radius - 1), acc, fn _j, {hex, list} ->
          new_hex = neighbor(hex, i)
          {new_hex, list ++ [hex]}
        end)
      end)

    list |> convert(func)
  end

  def ring(_center, _radius, _func), do: []

  defp convert([_ | _] = args, func) when func != nil do
    args |> Enum.map(&apply(func, [&1]))
  end

  defp convert([], _func), do: []

  defp convert(args, func) when func != nil do
    apply(func, [args])
  end

  defp convert(args, _func), do: args
end
