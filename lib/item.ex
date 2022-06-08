defmodule Item do
  use GameDef

  GameDef.defconf view: "items/all", transform: fn config ->
    config = GameDef.to_atom_key(config)

    if get_in(config, [:actions, :recover]) != nil do
      update_in(config, [:actions, :recover, :params], &GameDef.to_tagged_tuple/1)
    else
      config
    end
  end

  def get(_id) do
    nil
  end
end
