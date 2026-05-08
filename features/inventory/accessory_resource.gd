extends Resource

class_name AccessoryResource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var icon: Texture2D
@export var granted_spell: SpellResource
@export var passive_statuses: Array[PackedScene] = []

func to_info_data() -> Dictionary:
    return {
        "title": display_name,
        "icon": icon,
        "subtitle": "Accessory",
        "description": description,
        "lines": [],
    }
