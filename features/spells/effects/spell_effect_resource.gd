extends Resource

class_name SpellEffectResource

func execute(_info: SpellCastInfo) -> void:
    pass

## Override to reject invalid targets before a cast is even attempted.
func can_target(_caster: Combatant, _target: Combatant) -> bool:
    return true
