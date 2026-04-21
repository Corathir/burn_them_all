extends Node

class_name CombatManager

@onready var burning_system = $BurningSystem

var selected_spell: SpellResource

var current_heat: int = 50
var player_hp: int = 100

func _ready():
    EventBus.heat_changed.emit(current_heat)
    EventBus.target_selected.connect(_click_enemy)
    EventBus.spell_cast.connect(_spell_cast)
    EventBus.turn_ended.connect(_end_player_turn)

func _spend_heat(amount: int):
    current_heat -= amount
    EventBus.heat_changed.emit(current_heat)

func _gain_heat(amount: int):
    current_heat += amount
    EventBus.heat_changed.emit(current_heat)

func _click_enemy(enemy: Enemy):
    if (!selected_spell):
        return

    if selected_spell.ends_turn:
        var heat_gained = burning_system.collect_heat(enemy)
        _gain_heat(heat_gained)
        EventBus.log_entry.emit(selected_spell.spell_name + ' → ' + enemy.enemy_data.enemy_name + ' (+' + str(heat_gained) + ' Heat)')
        selected_spell = null
        EventBus.spell_resolved.emit()
        _end_player_turn()
    else:
        _spend_heat(selected_spell.heat_cost)
        if selected_spell.spell_name == "Spark":
            burning_system.ignite(enemy)
        EventBus.log_entry.emit(selected_spell.spell_name + ' → ' + enemy.enemy_data.enemy_name + ' (' + str(-1 * selected_spell.heat_cost) + ' Heat)')
        selected_spell = null
        EventBus.spell_resolved.emit()

func _spell_cast(spell: SpellResource):
    selected_spell = spell

func _end_player_turn():
    if current_heat > 100:
        var overflow_damage = current_heat - 100
        player_hp -= overflow_damage
        EventBus.log_entry.emit("Heat overflow! Player takes " + str(overflow_damage) + " damage")

    burning_system.advance_all()
    _enemy_phase()

func _enemy_phase():
    var enemies = get_tree().get_nodes_in_group("enemies")

    for enemy in enemies:
        var burn_stage = burning_system.get_stage(enemy)
        var damage = enemy.enemy_data.base_damage

        match burn_stage:
            burning_system.BurnStage.KINDLING, burning_system.BurnStage.FADING:
                damage = int(damage * 0.5)
            burning_system.BurnStage.BLAZING:
                damage = 0

        if damage > 0:
            player_hp -= damage
            EventBus.log_entry.emit(enemy.enemy_data.enemy_name + " attacks for " + str(damage) + " damage")
        elif burn_stage == burning_system.BurnStage.BLAZING:
            EventBus.log_entry.emit(enemy.enemy_data.enemy_name + " is Blazing - cannot attack!")
