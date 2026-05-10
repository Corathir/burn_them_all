extends Resource

class_name EnemyIntent

enum Kind { ATTACK, SPELL, BUFF, DEBUFF, UNKNOWN }

@export var kind: int = Kind.ATTACK
@export var amount: int = 0
@export var icon: Texture2D
@export var title: String
@export var description: String

func has_amount() -> bool:
    return amount > 0

func to_info_data() -> Dictionary:
    var lines: Array = []
    if amount != 0:
        lines.append({"label": _amount_label(), "value": str(amount)})
    return {
        "title": title,
        "icon": icon,
        "subtitle": _kind_label(),
        "description": description,
        "lines": lines,
    }

func _kind_label() -> String:
    match kind:
        Kind.ATTACK: return "Attack"
        Kind.SPELL: return "Spell"
        Kind.BUFF: return "Buff"
        Kind.DEBUFF: return "Debuff"
        _: return ""

func _amount_label() -> String:
    match kind:
        Kind.ATTACK, Kind.SPELL: return "Damage"
        _: return "Amount"
