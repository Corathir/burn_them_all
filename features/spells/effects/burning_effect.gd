extends SpellEffectResource

class_name BurningEffect

@export var reward: int = 20

func execute(info: SpellCastInfo) -> void:
    if info.target == null:
        return
    var burning_scene: PackedScene = load("res://features/statuses/burning/burning.tscn") as PackedScene
    if burning_scene == null:
        return
    info.target.statuses.apply(burning_scene, reward)
