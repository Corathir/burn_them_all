extends Control

class_name EnemyFormation

const ENEMY_SLOT_SCENE: PackedScene = preload("res://features/combatants/enemy/enemy_slot.tscn")

@export var formation: FormationResource

func _ready() -> void:
    _layout()

func populate(new_formation: FormationResource, entries: Array) -> void:
    formation = new_formation
    for child in get_children():
        if child is Enemy:
            child.queue_free()
    for entry in entries:
        var data: EnemyResource = entry.get("enemy_data")
        var scene: PackedScene = data.enemy_scene if data and data.enemy_scene else ENEMY_SLOT_SCENE
        var slot: Enemy = scene.instantiate()
        slot.slot_index = entry.get("slot_index", 0)
        slot.enemy_data = data
        add_child(slot)
    _layout()

func _layout() -> void:
    if formation == null:
        return
    var enemies: Array = []
    for child in get_children():
        if child is Enemy:
            enemies.append(child)
            _place(child as Enemy)
    _restack(enemies)

func _place(enemy: Enemy) -> void:
    var idx: int = enemy.slot_index
    if idx < 0 or idx >= formation.slots.size():
        push_warning("EnemyFormation: %s has slot_index %d outside formation '%s' (%d slots)" % [enemy.name, idx, formation.id, formation.slots.size()])
        return
    var slot: FormationSlot = formation.slots[idx]
    enemy.position = slot.position

func _restack(enemies: Array) -> void:
    enemies.sort_custom(_row_compare)
    for i in range(enemies.size()):
        move_child(enemies[i], i)

func _row_compare(a: Enemy, b: Enemy) -> bool:
    return _slot_row(a.slot_index) > _slot_row(b.slot_index)

func _slot_row(idx: int) -> int:
    if idx < 0 or idx >= formation.slots.size():
        return 0
    return formation.slots[idx].row
