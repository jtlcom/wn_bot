defmodule ClassBattle do
  
  def enter(lines \\ :all) do
    ["class_battle:enter"]
    |> Realm.broadcast_avatars(lines)
  end

  def leave(lines \\ :all) do
    ["class_battle:leave"]
    |> Realm.broadcast_avatars(lines)
  end

end