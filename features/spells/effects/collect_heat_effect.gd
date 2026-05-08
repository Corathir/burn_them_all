extends SpellEffectResource

class_name CollectHeatEffect

func execute(info: SpellCastInfo) -> void:
    if info.target == null:
        return
    var burning: BurningStatus = info.target.statuses.find(&"burning") as BurningStatus
    if burning == null:
        EventBus.log_entry.emit("Cannot collect from " + info.target.display_name)
        return
    var heat: int = burning.calculate_collect_value()
    if info.caster.has_method("gain_heat"):
        info.caster.gain_heat(heat)
    info.target.statuses.remove(&"burning")
    EventBus.log_entry.emit(info.spell.spell_name + " → " + info.target.display_name + " (+" + str(heat) + " Heat)")
