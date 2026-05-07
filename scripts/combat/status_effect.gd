extends Control

class_name StatusEffect

enum StackMode { DURATION, INTENSITY, REFRESH, UNIQUE }

@export var id: StringName
@export var display_name: String
@export var stack_mode: StackMode = StackMode.INTENSITY
@export var priority: int = 0

var stacks: int = 1
var host: Node

func on_apply() -> void:
    pass

func on_remove() -> void:
    pass

func on_stacks_changed(_delta: int) -> void:
    pass

func on_turn_start() -> void:
    pass

func on_turn_end() -> void:
    pass

func modify_outgoing_damage(_info: DamageInfo) -> void:
    pass

func modify_incoming_damage(_info: DamageInfo) -> void:
    pass

func on_damage_dealt(_info: DamageInfo) -> void:
    pass

func on_damage_taken(_info: DamageInfo) -> void:
    pass

func modify_pre_cast(_info: SpellCastInfo) -> void:
    pass

func modify_pre_cast_incoming(_info: SpellCastInfo) -> void:
    pass

func modify_post_cast(_info: SpellCastInfo) -> void:
    pass

func intercept_status_change(_req: StatusChangeRequest) -> void:
    pass
