defmodule InstanceCompleteMsg do

  def instance_complete_head() do
    [
      "short_treasure:complete",
      "battle_field:finished",
      "royal_mine:result",
      "storm_cellar:result",
      "thunder_forbidden:result"

    ]
  end

end