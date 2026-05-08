extends Resource

class_name BoundItemResource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var bound_spell_id: StringName
@export var modifier_status: PackedScene

func to_info_data() -> Dictionary:
    return {
        "title": display_name,
        "icon": icon,
        "subtitle": "Bound Item",
        "description": description,
        "lines": [],
    }
