extends SpellEffectResource

class_name CollectHeatEffect

func execute(info: SpellCastInfo) -> void:
    if not can_target(info.caster, info.target):
        return
    var burning: BurningStatus = info.target.statuses.find(&"burning") as BurningStatus
    burning.resolve_collect(info.caster, info.target)

func can_target(_caster: Combatant, target: Combatant) -> bool:
    if target == null:
        return false
    var burning: BurningStatus = target.statuses.find(&"burning") as BurningStatus
    return burning != null and burning.stage != BurningStatus.Stage.SMOLDERING
