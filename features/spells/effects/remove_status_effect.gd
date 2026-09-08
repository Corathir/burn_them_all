extends SpellEffectResource

class_name RemoveStatusEffect

@export var status_id: StringName
@export var apply_to_self: bool = true

func execute(info: SpellCastInfo) -> void:
    var host: Combatant = info.caster if apply_to_self else info.target
    if host == null:
        return
    host.statuses.remove(status_id)
