extends Node

class_name Arena

@export var def: ArenaResource

@onready var statuses: StatusContainer = %StatusContainer

var is_arena: bool = true

func _ready() -> void:
    CombatContext.arena = self

func enter_battle() -> void:
    if def == null:
        return
    for entry in def.battle_start_effects:
        for combatant in _resolve_targets(entry.target_filter):
            combatant.statuses.apply(entry.status_scene, entry.stacks)
    for s in def.permanent_statuses:
        statuses.apply(s)

func _resolve_targets(filter: int) -> Array[Combatant]:
    match filter:
        ArenaBattleStartEntry.TargetFilter.PLAYER:
            var arr: Array[Combatant] = []
            if CombatContext.player:
                arr.append(CombatContext.player)
            return arr
        ArenaBattleStartEntry.TargetFilter.ENEMIES:
            return CombatContext.enemies.duplicate()
        ArenaBattleStartEntry.TargetFilter.ALL:
            return CombatContext.all_combatants()
    return []
