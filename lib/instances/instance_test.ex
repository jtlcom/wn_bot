defmodule InstanceTest do

  def enter(lines \\ :all) do
    ["instance", 203011]
    |> Realm.broadcast_avatars(lines)
  end

end