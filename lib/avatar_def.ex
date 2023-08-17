defmodule AvatarDef do
  defstruct id: 0,
            account: "",
            name: "",
            conn: nil,
            buildings: %{},
            city_pos: nil,
            gid: 0,
            grids: %{},
            grids_limit: 10,
            heros: %{},
            points: %{},
            troops: %{},
            units: %{},
            fixed_units: %{},
            dynamic_units: %{},
            AI: false
end
