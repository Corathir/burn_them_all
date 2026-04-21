extends Node

class_name CombatManager

var selected_spell: SpellResource

var current_heat: int = 50

func _ready():
    EventBus.heat_changed.emit(current_heat)
    EventBus.target_selected.connect(_click_enemy)
    EventBus.spell_cast.connect(_spell_cast)

func _spend_heat(amount: int):
    current_heat -= amount
    EventBus.heat_changed.emit(current_heat)

func _gain_heat(amount: int):
    current_heat += amount
    EventBus.heat_changed.emit(current_heat)

func _click_enemy(enemy: Enemy):
    if (!selected_spell):
        return

    _spend_heat(selected_spell.heat_cost)
    EventBus.log_entry.emit(selected_spell.spell_name + ' → ' + enemy.enemy_data.enemy_name + ' (' + str(-1 * selected_spell.heat_cost) + ' Heat)')
    selected_spell = null
    EventBus.spell_resolved.emit()

func _spell_cast(spell: SpellResource):
    selected_spell = spell
