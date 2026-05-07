extends Node

var player: Combatant
var enemies: Array[Combatant] = []
var arena: Node

func all_combatants() -> Array[Combatant]:
    var result: Array[Combatant] = []
    if player:
        result.append(player)
    for e in enemies:
        result.append(e)
    return result

func reset() -> void:
    player = null
    enemies.clear()
    arena = null
