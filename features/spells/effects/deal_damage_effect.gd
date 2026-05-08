extends SpellEffectResource

class_name DealDamageEffect

@export var amount: int
@export var damage_type: int = DamageInfo.Type.SPELL

func execute(info: SpellCastInfo) -> void:
    if info.target == null:
        return
    info.caster.deal_damage(info.target, amount, damage_type, info.spell.id)
