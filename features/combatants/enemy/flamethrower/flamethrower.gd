extends Enemy

class_name Flamethrower

func take_turn(target: Combatant) -> void:
    if target == null or hp <= 0:
        return
    var has_burning := statuses.find(&"burning") != null
    if has_burning and (next_intent == null or next_intent.kind != EnemyIntent.Kind.ATTACK):
        var purify := _find_spell(&"purify")
        if purify:
            cast(purify, null)
            plan_next_action()
            return
    var attack := _find_spell(&"attack")
    if attack:
        cast(attack, target)
    plan_next_action()

func _build_intent() -> EnemyIntent:
    if enemy_data == null or hp <= 0:
        return null
    var intent := EnemyIntent.new()
    if statuses.find(&"burning") != null:
        var purify := _find_spell(&"purify")
        if purify:
            intent.kind = EnemyIntent.Kind.BUFF
            intent.icon = purify.icon
            intent.title = purify.spell_name
            intent.description = purify.description
            return intent
    var attack := _find_spell(&"attack")
    if attack:
        intent.kind = EnemyIntent.Kind.ATTACK
        intent.amount = _sum_damage(attack.effects)
        intent.icon = attack.icon if attack.icon else ATTACK_INTENT_ICON
        intent.title = display_name
        intent.description = "Strikes the player for %d damage." % intent.amount
        return intent
    return null

func _find_spell(spell_id: StringName) -> SpellResource:
    for s in spellbook.spells:
        if s.id == spell_id:
            return s
    return null
