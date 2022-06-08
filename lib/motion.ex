defmodule Motion do
  @moduledoc "handle movement calculation"
  alias Graphmath.Vec2

  require Logger

  def init(%{x: x, y: y}) do
    {:still, x, y}
  end

  def peek(motion), do: Motion.apply(motion, :peek)

  # take a look of current motion info, motion => pos + motion
  def apply({:still, x, y} = motion, :peek) do
    {{x, y}, motion}
  end

  def apply({:moving, fx, fy, tx, ty, ts, speed}, :peek) do
    diff = Vec2.subtract({tx, ty}, {fx, fy})
    duration = Vec2.length(diff) * 1000 / speed
    now = System.system_time(:millisecond)
    passed = now - ts
#    Logger.debug "duration is #{duration}, passed is #{passed}"

    if passed >= duration do
      {{tx, ty}, {:still, tx, ty}}
    else
      {x, y} = Vec2.lerp({fx, fy}, {tx, ty}, passed / duration)
      {{x, y}, {:moving, x, y, tx, ty, now, speed}}
    end
  end

  def apply(motion, {:move, x, y, speed}) do
    {{fx, fy} = pos, _mot} = peek(motion)
    forward = %{x: (x - fx), y: (y - fy)}
    {pos, {:moving, fx, fy, x, y, System.system_time(:millisecond), speed}, forward}
  end
end
