extends Button

class_name LogButton

@export var combat_log_path: NodePath

var _combat_log: CombatLog

func _ready() -> void:
    if combat_log_path != NodePath():
        _combat_log = get_node(combat_log_path) as CombatLog
    pressed.connect(_on_pressed)
    if _combat_log:
        _combat_log.closed.connect(_on_log_closed)
        visible = not _combat_log.visible

func _on_pressed() -> void:
    if _combat_log == null:
        return
    _combat_log.open()
    visible = false

func _on_log_closed() -> void:
    visible = true