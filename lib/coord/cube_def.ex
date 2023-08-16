defmodule CubeDef do
  import Bitwise

  defstruct q: 0,
            r: 0,
            s: 0

  @type t :: %__MODULE__{
          q: integer(),
          r: integer(),
          s: integer()
        }

  def new(:axial, q, r) do
    new(q, r, -q - r)
  end

  def new(q, r, s) do
    struct(%__MODULE__{}, q: q, r: r, s: s)
  end

  def new({q, r, s}) do
    struct(%__MODULE__{}, q: q, r: r, s: s)
  end

  def new({x, y}) do
    q = trunc(x - (y - (y &&& 1)) / 2)
    r = y
    s = -q - r
    new(q, r, s)
  end

  def new(_), do: nil

  def new(x, y) do
    new({x, y})
  end

  def to_oddr(%CubeDef{} = cube) do
    x = trunc(cube.q + (cube.r - (cube.r &&& 1)) / 2)
    y = cube.r
    {x, y}
  end

  def to_axial(%CubeDef{} = cube) do
    {cube.q, cube.r}
  end

  def to_tuple(%CubeDef{} = cube) do
    {cube.q, cube.r, cube.s}
  end

  def scale(%CubeDef{} = cube, factor) do
    struct(cube, q: cube.q * factor, r: cube.r * factor, s: cube.s * factor)
  end

  def add(%CubeDef{} = cube, %CubeDef{} = val) do
    struct(cube, q: cube.q + val.q, r: cube.r + val.r, s: cube.s + val.s)
  end

  def dec(%CubeDef{} = cube, %CubeDef{} = val) do
    struct(cube, q: cube.q - val.q, r: cube.r - val.r, s: cube.s - val.s)
  end
end
