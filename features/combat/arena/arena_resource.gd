extends Resource

class_name ArenaResource

@export var id: StringName
@export var display_name: String
@export var background: Texture2D
@export var battle_start_effects: Array[ArenaBattleStartEntry] = []
@export var permanent_statuses: Array[PackedScene] = []
