extends Control

class_name StatusEffect

enum StackMode { DURATION, INTENSITY, REFRESH, UNIQUE }

@export var id: StringName
@export var display_name: String
@export var stack_mode: StackMode = StackMode.INTENSITY
@export var priority: int = 0
@export var negative: bool = false

var stacks: int = 1
var host: Node

func _ready() -> void:
    for child in get_children():
        if child is Control:
            (child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func to_info_data() -> Dictionary:
    var lines: Array = []
    if stacks > 0:
        lines.append({"label": "Stacks", "value": str(stacks)})
    return {
        "title": display_name,
        "subtitle": "Status",
        "description": "",
        "lines": lines,
    }

func _on_mouse_entered() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.show_for(self, to_info_data())

func _on_mouse_exited() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.hide_panel()

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
