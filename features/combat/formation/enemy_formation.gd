extends Control

class_name EnemyFormation

const ENEMY_SLOT_SCENE: PackedScene = preload("res://features/combatants/enemy/enemy_slot.tscn")

@export var formation: FormationResource

func _ready() -> void:
    CombatContext.formation = self
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

## Live (hp > 0) enemies sharing the row and an adjacent column with `enemy`.
func get_neighbors(enemy: Enemy) -> Array[Enemy]:
    var result: Array[Enemy] = []
    var slot: FormationSlot = _slot_for(enemy)
    if slot == null:
        return result
    for child in get_children():
        if not (child is Enemy) or child == enemy or not is_instance_valid(child):
            continue
        var other: Enemy = child as Enemy
        if other.hp <= 0:
            continue
        var other_slot: FormationSlot = _slot_for(other)
        if other_slot == null:
            continue
        if other_slot.row == slot.row and absi(other_slot.column - slot.column) == 1:
            result.append(other)
    return result

func _slot_for(enemy: Enemy) -> FormationSlot:
    if formation == null:
        return null
    var idx: int = enemy.slot_index
    if idx < 0 or idx >= formation.slots.size():
        return null
    return formation.slots[idx]
