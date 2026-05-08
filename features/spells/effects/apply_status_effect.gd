extends SpellEffectResource

class_name ApplyStatusEffect

@export var status_scene: PackedScene
@export var stacks: int = 1
@export var apply_to_self: bool = false

func execute(info: SpellCastInfo) -> void:
    if status_scene == null:
        return
    var target: Combatant = info.caster if apply_to_self else info.target
    if target == null:
        return
    target.statuses.apply(status_scene, stacks)
