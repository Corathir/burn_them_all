extends Resource

class_name SpellResource

@export var id: StringName
@export var spell_name: String
@export var heat_cost: int
@export var heat_reward: int = 0
@export var ends_turn: bool
@export var description: String
@export var target_type: TargetType
@export var icon: Texture2D
@export var icon_active: Texture2D
@export var applies_status: PackedScene
@export var effects: Array = []

enum TargetType {
    SINGLE_ENEMY,
    SINGLE_BURNABLE,
    ALL_BURNING,
    SELF,
    NONE
}

func effective_heat_cost(caster: Combatant = null) -> int:
    if caster == null:
        return heat_cost
    var info: SpellCastInfo = caster.preview_spell(self)
    var delta: int = info.extra_data.get("heat_cost_delta", 0)
    return max(0, heat_cost + delta)

func to_info_data(caster: Combatant = null) -> Dictionary:
    var lines: Array = []
    var info: SpellCastInfo = caster.preview_spell(self) if caster != null else null
    var cost_delta: int = 0
    if info:
        cost_delta = info.extra_data.get("heat_cost_delta", 0)

    if heat_cost != 0 or cost_delta != 0:
        lines.append({"label": "Heat cost", "value": _format_with_delta(heat_cost, cost_delta)})
    if heat_reward != 0:
        lines.append({"label": "Heat reward", "value": str(heat_reward)})

    var base_damage: int = _sum_damage(effects)
    var damage_delta: int = 0
    if info:
        damage_delta = _sum_damage(info.effects) - base_damage
    if base_damage != 0 or damage_delta != 0:
        lines.append({"label": "Damage", "value": _format_with_delta(base_damage, damage_delta)})

    if ends_turn:
        lines.append({"label": "Ends turn", "value": "yes"})
    return {
        "title": spell_name,
        "icon": icon,
        "subtitle": "Spell",
        "description": description,
        "lines": lines,
    }

func _sum_damage(effect_list: Array) -> int:
    var total: int = 0
    for effect in effect_list:
        if effect is DealDamageEffect:
            total += (effect as DealDamageEffect).amount
    return total

func _format_with_delta(base: int, delta: int) -> String:
    if delta == 0:
        return str(base)
    var sign: String = "+" if delta > 0 else ""
    return str(base) + " (" + sign + str(delta) + ")"
