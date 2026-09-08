extends SpellEffectResource

class_name CollectHeatEffect

func execute(info: SpellCastInfo) -> void:
    if not can_target(info.caster, info.target):
        return
    var burning: BurningStatus = info.target.statuses.find(&"burning") as BurningStatus
    var heat: int = burning.calculate_collect_value()
    if info.caster.has_method("gain_heat"):
        info.caster.gain_heat(heat)
    info.target.statuses.remove(&"burning")
    EventBus.log_entry.emit(info.spell.spell_name + " → " + info.target.display_name + " (+" + str(heat) + " Heat)")

func can_target(_caster: Combatant, target: Combatant) -> bool:
    if target == null:
        return false
    var burning: BurningStatus = target.statuses.find(&"burning") as BurningStatus
    return burning != null and burning.stage != BurningStatus.Stage.SMOLDERING
