extends Node

class_name CombatManager

@onready var arena: Arena = $Arena

func _ready() -> void:
    EventBus.target_selected.connect(_on_target_selected)
    EventBus.spell_cast.connect(_on_spell_cast)
    EventBus.turn_ended.connect(_end_player_turn)
    EventBus.spell_selection_canceled.connect(_on_spell_selection_canceled)
    _start_combat.call_deferred()

func _start_combat() -> void:
    if arena:
        arena.enter_battle()
    if CombatContext.player:
        EventBus.turn_started.emit(CombatContext.player)

func _on_spell_cast(spell: SpellResource) -> void:
    CombatContext.selected_spell = null
    if spell.target_type == SpellResource.TargetType.SELF:
        if CombatContext.player and CombatContext.player.cast(spell, null):
            EventBus.log_entry.emit(spell.spell_name + " (" + str(-1 * spell.heat_cost) + " Heat)")
        EventBus.spell_resolved.emit()
        return
    CombatContext.selected_spell = spell

func _on_spell_selection_canceled() -> void:
    CombatContext.selected_spell = null

func _on_target_selected(enemy) -> void:
    if CombatContext.selected_spell == null:
        return
    if CombatContext.player == null:
        return
    var spell: SpellResource = CombatContext.selected_spell
    var ok: bool = CombatContext.player.cast(spell, enemy)
    CombatContext.selected_spell = null
    EventBus.spell_resolved.emit()
    if not ok:
        return
    if not spell.ends_turn and (spell.effects.is_empty() or _is_simple_damage(spell)):
        var dmg_log: String = spell.spell_name + " → " + (enemy.display_name if enemy is Combatant else "?")
        if spell.heat_cost > 0:
            dmg_log += " (" + str(-1 * spell.heat_cost) + " Heat)"
        EventBus.log_entry.emit(dmg_log)
    if spell.ends_turn:
        _end_player_turn()

func _is_simple_damage(_spell: SpellResource) -> bool:
    return true

func _end_player_turn() -> void:
    if CombatContext.player == null:
        return
    EventBus.turn_ended_by.emit(CombatContext.player)
    var p: Player = CombatContext.player as Player
    if p and p.heat > p.overflow_threshold:
        var overflow: int = p.heat - p.overflow_threshold
        p.apply_raw_damage(overflow)
        EventBus.log_entry.emit("Heat overflow! Player takes " + str(overflow) + " damage")
    _enemy_phase()
    if CombatContext.player:
        EventBus.turn_started.emit(CombatContext.player)

func _enemy_phase() -> void:
    var enemies: Array = CombatContext.enemies.duplicate()
    for enemy in enemies:
        if not is_instance_valid(enemy) or enemy.hp <= 0:
            continue
        EventBus.turn_started.emit(enemy)
        if enemy.hp > 0:
            enemy.take_turn(CombatContext.player)
        EventBus.turn_ended_by.emit(enemy)
