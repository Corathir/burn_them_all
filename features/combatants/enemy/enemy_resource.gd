extends Resource

class_name EnemyResource

@export var id: StringName
@export var enemy_name: String
@export var max_hp: int
@export var base_damage: int
@export var description: String
@export var sprite: Texture2D
@export var spells: Array[SpellResource] = []
@export var initial_statuses: Array[PackedScene] = []
