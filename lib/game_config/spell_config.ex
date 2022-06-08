###############################################################
# 正式技能表，spell, stage, effect, missile, buff, spellField #
###############################################################

defmodule SpellStruct do
  defstruct id: 0,
    name: 0,
    job: 0,
#    level: 0,
    type: 0,
    triggerType: 0,
    triggerArgs: 0,
    attackType: 0,
    xp: 0,
    fury: 0,
    lockEnemyType: 0,
    distance: 0,
    lockEnemyAngle: 0,
    cd: 0,
    gcd: 0,
    checkGcd: 0,
    awakeSkillId: 0,
    triggerSkillCondition: 0,
    triggerSkillId: 0,
    icon: 0,
    description: 0,
    levelUpCost: 0,
    levelUpItem: {0, 0},
    levelUpLevel: 0,
    isMaxLevel: 0,
    skillStages: [],
    eudemonSpellLevels: nil
end

defmodule SpellStageStruct do
  defstruct id: 0,
    duration: 0,
    invincible: 0,
    canMove: 0,
    canControl: 0,
    isRemoveLock: 0,
    filterSpells: [],
    isLockTarget: [],
    refTargetPoint: 0,
    attackWay: 0,
    aoeType: 0,
    aoeRadius: 0,
    aoeAngle: 0,
    aoeWidth: 0,
    aoeHeight: 0,
    targetLimit: 0,
    effects: []
end

defmodule SpellEffectStruct do
  defstruct id: 0,
    level: 0,
    targetType: 0,
    camp: 0,
    effectTargetType: 0,
    targetLimit: 0,
    delayTime: 0,
    effectType: 0,
    effectPercent: 0,
    effectValue: 0,
    critical: 0,
    hitRating: 0,
    notFirstTargetPercent: 0,
    transpositionTime: 0,
    transposition: 0,
    missileId: 0,
    spellFieldId: 0,
    buffId: 0,
    triggerSpellId: 0,
    triggerSpellPercent: 0,
    isLastDamage: false,
    playerEffectPercent: 0,
    typeArgs: []
end

defmodule MissileStruct do
  defstruct id: 0,
    missileNumber: 0,
    plusTime: 0,
    plusMax: 0,
    position: 0,
    angle: 0,
    moveWay: 0,
    delayTime: 0,
    duration: 0,
    displayEffectId: 0,
    camp: 0,
    canPenetration: 0,
    maxPenetration: 0,
    damageReducePercent: 0,
    speed: 0,
    acceleration: 0,
    missileWidth: 0,
    removeCondition: 0,
    buffId: 0,
    effectId: 0,
    aoeType: 0,
    aoeRadius: 0,
    aoeAngle: 0,
    aoeWidth: 0,
    aoeHeight: 0,
    targetLimit: 0
end

defmodule BuffStruct do
  defstruct id: 0,
    level: 0,
    isControl: 0,
    triggerType: 0,
    triggerArgs: 0,
    aoeType: 0,
    aoeRadius: 0,
    aoeAngle: 0,
    aoeWidth: 0,
    aoeHeight: 0,
    conditionRate: 0,
    influenceType: 0,
    canDispel: 0,
    effectTargetType: 0,
    effectType: 0,
    effectValue: 0,
    effectPercent: 0,
    duration: 0,
    gapTime: 0,
    canCover: 0,
    canSuperposition: 0,
    removeCondition: 0,
    displayEffectId: 0
end

defmodule SpellFieldStruct do
  defstruct id: 0,
    spellFieldNum: 0,
    position: 0,
    aoeType: 0,
    aoeRadius: 0,
    aoeAngle: 0,
    aoeWidth: 0,
    aoeHeight: 0,
    isFollowStage: 0,
    duration: 0,
    displayEffectId: 0,
    camp: 0,
    isTriggerDisappear: 0,
    buffId: 0,
    gapTime: 0
end

defmodule SpellConfig do

  use GameDef
  require Logger

  GameDef.defconf view: "spells/spell", getter: :by_spell, as: SpellStruct
  GameDef.defconf view: "spells/spell_stages", getter: :by_stage, as: SpellStageStruct
  GameDef.defconf view: "spells/spell_effects", getter: :by_effect, as: SpellEffectStruct
  GameDef.defconf view: "spells/missile", getter: :by_missile, as: MissileStruct
  GameDef.defconf view: "spells/buff", getter: :by_buff, as: BuffStruct
  GameDef.defconf view: "spells/spell_field", getter: :by_spell_field, as: SpellFieldStruct

  GameDef.defconf view: "levels/class_args", getter: :by_class_args

  def get_spell_total_time(spell_id, level) do
    %{skillStages: stages} = by_spell spell_id, level
    fun = fn(stage_id, acc) ->
      %{duration: duration} = by_stage stage_id
      acc + duration
    end
    Enum.reduce(stages, 0, fun)
  end

end
