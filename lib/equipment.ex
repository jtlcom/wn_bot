defmodule Equipment do
  use GameDef
  
  GameDef.load_rows("equipments/all")
  |> Enum.each(fn row ->
    config = GameDef.to_atom_key(row["value"])
    def get(unquote(row["key"])), do: unquote(Macro.escape(config))
  end)
  @all_pos_id GameDef.load_rows("equipments/equip_pos_unlock") |> Enum.map(& &1["key"])
  GameDef.defconf view: "equipments/equip_pos_unlock", getter: :pos_unlock

  def all_pos_id(), do: @all_pos_id
  def get(_), do: nil

  def extra_conf(equip_id) do
    %{rank: rank, slot: slot} = get(equip_id)

    Enum.reduce(@all_pos_id, %{}, fn pos_id, acc ->
      cond do
        slot <= 8 ->
          %{stage: [min, max]} = pos_unlock(pos_id)

          (rank in min..max &&
             (
               %{pos: pos, forge: forge, suit: suit} = pos_unlock(pos_id)

               Map.merge(acc, %{
                 pos: Map.get(acc, :pos, []) ++ [pos],
                 forge: Map.get(acc, :forge, []) ++ [forge],
                 suit: Map.get(acc, :suit, []) ++ [suit]
               })
             )) || acc

        true ->
          %{ring_stage: [min, max]} = pos_unlock(pos_id)

          (rank in min..max &&
             (
               %{pos: pos, forge: forge, suit: suit} = pos_unlock(pos_id)

               Map.merge(acc, %{
                 pos: Map.get(acc, :pos, []) ++ [pos],
                 forge: Map.get(acc, :forge, []) ++ [forge],
                 suit: Map.get(acc, :suit, []) ++ [suit]
               })
             )) || acc
      end
    end)
  end
  
  def equip(lines \\ :all) do
    :gm_equip
    |> Realm.broadcast_avatars_handle(lines)
  end

  def unequip(lines \\ :all) do
    :gm_unequip
    |> Realm.broadcast_avatars_handle(lines)
  end

  def add_equips(lines \\ :all) do
    Application.get_env(:pressure_test, :equipments)
    |> Map.values
    |> List.flatten()
    |> Enum.map(&(["gm:add_item", &1, 1]))
    |> Enum.each(&(Realm.broadcast_avatars(&1, lines)))
  end

end