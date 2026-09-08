extends Node

var player: Combatant
var enemies: Array[Combatant] = []
var arena: Node
var info_panel: InfoPanel
var selected_spell: SpellResource

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
    info_panel = null
    selected_spell = null
