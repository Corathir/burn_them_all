extends StatusEffect

class_name HeatTouchHelmMod

const BONUS_DAMAGE: int = 10

func _init() -> void:
    id = &"mod_heat_touch_helm"
    display_name = "Heat Touch Helm"
    stack_mode = StackMode.UNIQUE
    priority = 0

func modify_pre_cast(info: SpellCastInfo) -> void:
    if info.spell == null or info.spell.id != &"heat_touch":
        return
    var dmg := DealDamageEffect.new()
    dmg.amount = BONUS_DAMAGE
    dmg.damage_type = DamageInfo.Type.SPELL
    info.effects.append(dmg)
