extends RefCounted

class_name DamageInfo

enum Type { ATTACK, SPELL, BURNING, OVERFLOW, PURE }

var amount: int
var type: Type
var source: Combatant
var target: Combatant
var ability_id: StringName
var canceled: bool = false