extends Resource

class_name ArenaBattleStartEntry

enum TargetFilter { PLAYER, ENEMIES, ALL }

@export var target_filter: TargetFilter
@export var status_scene: PackedScene
@export var stacks: int = 1
