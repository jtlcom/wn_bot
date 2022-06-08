defmodule MindQuiz do

  def enter(lines \\ :all) do
    ["mind_quiz:player_enter"]
    |> Realm.broadcast_avatars(lines)
  end

  def leave(lines \\ :all) do
    ["mind_quiz:player_leave"]
    |> Realm.broadcast_avatars(lines)
  end

end