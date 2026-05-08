extends StatusEffect

class_name MaxHeatMod

const THRESHOLD_BONUS: int = 10

func _init() -> void:
    id = &"mod_max_heat"
    display_name = "Heat Amulet"
    stack_mode = StackMode.UNIQUE
    priority = 0

func on_apply() -> void:
    var p: Player = host as Player
    if p == null:
        return
    p.overflow_threshold += THRESHOLD_BONUS
    EventBus.heat_changed.emit(p.heat)

func on_remove() -> void:
    var p: Player = host as Player
    if p == null:
        return
    p.overflow_threshold -= THRESHOLD_BONUS
    EventBus.heat_changed.emit(p.heat)
