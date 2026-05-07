extends StatusEffect

class_name ShieldStatus

@onready var icon: TextureRect = $Icon
@onready var charges_label: Label = $ChargesLabel

func _init() -> void:
    id = &"shield"
    display_name = "Shield"
    stack_mode = StackMode.INTENSITY
    priority = 10

func on_apply() -> void:
    _update_visual()

func on_stacks_changed(_delta: int) -> void:
    _update_visual()

func modify_incoming_damage(info: DamageInfo) -> void:
    if info.canceled or info.amount <= 0:
        return
    if stacks <= 0:
        return
    info.amount = 0
    info.canceled = true
    EventBus.log_entry.emit("Shield blocks the attack")
    (host as Combatant).statuses.remove_stack(id, 1)

func to_info_data() -> Dictionary:
    var data: Dictionary = super.to_info_data()
    if icon and icon.texture:
        data["icon"] = icon.texture
    data["description"] = "Blocks the next incoming attack and consumes one charge."
    return data

func _update_visual() -> void:
    if charges_label:
        charges_label.text = str(stacks)
        charges_label.visible = stacks > 1
