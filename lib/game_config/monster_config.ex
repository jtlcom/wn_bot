defmodule MonsterConfigDef do

  defstruct id: 0,
    name: "",
    type: 0,
    camp: 0,
    aiType: 0,
    guardRange: 0,
    chaseRange: 0,
    level: 0,
    speed: 0,
    disappearTime: 0,
    rebornTime: 0,
    dropId: 0,
    dropProTime: 0,
    dropDisTime: 0,
    exp: 0,
    currencyType: 0,
    currencyMin: 0,
    currencyMax: 0,
    canStun: 0,
    canImmo: 0,
    canReduceSpeed: 0,
    battleTypeId: 0,
    spells: [],
    hypsokinesis: 0,
    hypsRecovery: 0,
    hypsTimeTick: 0,
    canRepulse: 0,
    canBeatFly: 0,
    canFloat: 0,
    hpBarNum: 0,
    scriptPath: 0,

    physicalAttack: 10,
    minPhysicalAttack: 15,
    maxPhysicalAttack: 100,
    magicAttack: 10,
    minMagicAttack: 0,
    maxMagicAttack: 0,
    armor: 10,
    resistance: 10,
    health: 100,
    fury: 100,
    maxXP: 100,
    xpRecovery: 0,
    hitRating: 10,
    dodgeRating: 10,
    criticalChance: 10,
    criticalRating: 10,
    criticalDamage: 10,
    criticalDamageRating: 100,
    criticalResistance: 10,
    criticalResistanceRating: 10,
    criticalDamageReduction: 10,
    criticalDamageReductionRating: 10,
    damageReduction: 10,
    physicalDamageReduction: 10,
    magicDamageReduction: 10,
    damageIncrease: 10,
    physicalDamageIncrease: 10,
    magicDamageIncrease: 10,
    trueDamageIncrease: 10,
    trueDamageReduction: 100

end

## monster 战斗属性
defmodule MonsterPropsConfigDef do
  defstruct id: 0,
    physicalAttack: 10,
    minPhysicalAttack: 15,
    maxPhysicalAttack: 100,
    magicAttack: 10,
    minMagicAttack: 0,
    maxMagicAttack: 0,
    armor: 10,
    resistance: 10,
    health: 100,
    fury: 100,
    maxXP: 100,
    xpRecovery: 0,
    hitRating: 10,
    dodgeRating: 10,
    criticalChance: 10,
    criticalRating: 10,
    criticalDamage: 10,
    criticalDamageRating: 100,
    criticalResistance: 10,
    criticalResistanceRating: 10,
    criticalDamageReduction: 10,
    criticalDamageReductionRating: 10,
    damageReduction: 10,
    physicalDamageReduction: 10,
    magicDamageReduction: 10,
    damageIncrease: 10,
    physicalDamageIncrease: 10,
    magicDamageIncrease: 10,
    trueDamageIncrease: 10,
    trueDamageReduction: 100
end

# defmodule MonsterConfig do

#   use GameDef

#   GameDef.defconf view: "actors/monsters", transform: fn config ->
#     config
#     |> GameDef.to_atom_key
#     |> Map.update!(:spells, fn spells -> spells |> Enum.map(&GameDef.to_atom_key/1) end)
#   end

# end

defmodule MonsterConfig do

  use GameDef
  GameDef.defconf view: "actors/monster_props", transform: fn config ->
    config
    |> GameDef.to_atom_key
    |> Map.update!(:stats, fn stat -> stat |> Enum.map(&GameDef.to_atom_key/1) end)
    |> Map.update!(:stats, fn stat -> stat |> Enum.into(%{}) end)
  end

  GameDef.defconf view: "actors/dynamic_monster", getter: :dynamic_monster
end
