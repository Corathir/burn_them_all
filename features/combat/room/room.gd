extends Control

class_name Room

@export var arena_def: ArenaResource
@export var formation: FormationResource
@export var enemies: Array[RoomEnemyEntry] = []

@onready var enemy_formation: EnemyFormation = $EnemyFormation

func _ready() -> void:
    var arena: Arena = CombatContext.arena as Arena
    if arena and arena_def:
        arena.def = arena_def
    var entries: Array = []
    for entry in enemies:
        if entry == null or entry.enemy_data == null:
            continue
        entries.append({"slot_index": entry.slot_index, "enemy_data": entry.enemy_data})
    enemy_formation.populate(formation, entries)
