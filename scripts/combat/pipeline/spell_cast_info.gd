extends RefCounted

class_name SpellCastInfo

var spell: SpellResource
var caster: Combatant
var target: Combatant
var effects: Array
var canceled: bool = false
var extra_data: Dictionary = {}
