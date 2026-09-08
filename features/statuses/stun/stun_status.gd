extends StatusEffect

class_name StunStatus

func _init() -> void:
    id = &"stun"
    display_name = "Stunned"
    stack_mode = StackMode.UNIQUE
    negative = true

func blocks_turn() -> bool:
    return true

func to_info_data() -> Dictionary:
    var data: Dictionary = super.to_info_data()
    data["description"] = "Skips this combatant's next turn."
    return data
