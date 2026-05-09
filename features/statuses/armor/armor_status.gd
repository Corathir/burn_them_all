extends StatusEffect

class_name ArmorStatus

@onready var icon: TextureRect = $Icon

func _init() -> void:
    id = &"armor"
    display_name = "Armor"
    stack_mode = StackMode.UNIQUE
    priority = 50

func modify_incoming_damage(info: DamageInfo) -> void:
    if info.canceled or info.amount <= 0:
        return
    var absorbed: int = info.amount
    info.amount = 0
    info.canceled = true
    var p: Player = host as Player
    if p:
        p.gain_heat(absorbed)
        EventBus.log_entry.emit("Armor absorbs " + str(absorbed) + " damage (+" + str(absorbed) + " Heat)")
    else:
        EventBus.log_entry.emit("Armor absorbs " + str(absorbed) + " damage")

func on_turn_start() -> void:
    (host as Combatant).statuses.remove(id)

func to_info_data() -> Dictionary:
    var data: Dictionary = super.to_info_data()
    if icon and icon.texture:
        data["icon"] = icon.texture
    data["description"] = "Absorbs incoming damage and converts it to Heat. Removed at the start of your next turn."
    return data
