extends Resource

class_name SpellResource

@export var id: StringName
@export var spell_name: String
@export var heat_cost: int
@export var heat_reward: int = 0
@export var ends_turn: bool
@export var description: String
@export var target_type: TargetType
@export var icon: Texture2D
@export var icon_active: Texture2D
@export var applies_status: PackedScene
@export var effects: Array = []

enum TargetType {
    SINGLE_ENEMY,
    SINGLE_BURNABLE,
    ALL_BURNING,
    SELF,
    NONE
}

func to_info_data() -> Dictionary:
    var lines: Array = []
    if heat_cost != 0:
        lines.append({"label": "Heat cost", "value": str(heat_cost)})
    if heat_reward != 0:
        lines.append({"label": "Heat reward", "value": str(heat_reward)})
    if ends_turn:
        lines.append({"label": "Ends turn", "value": "yes"})
    return {
        "title": spell_name,
        "icon": icon,
        "subtitle": "Spell",
        "description": description,
        "lines": lines,
    }
