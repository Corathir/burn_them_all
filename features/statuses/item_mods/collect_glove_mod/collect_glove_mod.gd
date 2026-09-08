extends StatusEffect

class_name CollectGloveMod

const BONUS: int = 5

func _init() -> void:
    id = &"mod_collect_glove"
    display_name = "Collector's Glove"
    stack_mode = StackMode.UNIQUE
    priority = 0

func modify_pre_cast(info: SpellCastInfo) -> void:
    if info.spell == null or info.spell.id != &"collect_heat":
        return
    var burning: BurningStatus = null
    if info.target != null and info.target.statuses != null:
        burning = info.target.statuses.find(&"burning") as BurningStatus
    var can_collect: bool = burning != null and burning.stage != BurningStatus.Stage.SMOLDERING
    info.extra_data["collect_glove_active"] = can_collect

func modify_post_cast(info: SpellCastInfo) -> void:
    if info.spell == null or info.spell.id != &"collect_heat":
        return
    if not info.extra_data.get("collect_glove_active", false):
        return
    if info.caster and info.caster.has_method("gain_heat"):
        info.caster.gain_heat(BONUS)
        EventBus.log_entry.emit("Collector's Glove (+" + str(BONUS) + " Heat)")
