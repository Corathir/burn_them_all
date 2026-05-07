extends Resource

class_name AccessoryResource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var granted_spell: SpellResource
@export var passive_statuses: Array[PackedScene] = []
