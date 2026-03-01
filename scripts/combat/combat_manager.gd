extends Node

class_name CombatManager

var current_heat: int = 50

func _ready():
    EventBus.heat_changed.emit(current_heat)
    EventBus.target_selected.connect(_click_enemy)

func _spend_heat(amount: int):
    current_heat -= amount
    EventBus.heat_changed.emit(current_heat)

func _gain_heat(amount: int):
    current_heat += amount
    EventBus.heat_changed.emit(current_heat)

func _click_enemy(enemy: Enemy):
    enemy.get_damage(10)
    _spend_heat(10)
