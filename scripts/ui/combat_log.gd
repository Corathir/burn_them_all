extends Control

class_name CombatLog

signal closed

func _ready() -> void:
    EventBus.log_entry.connect(_on_log_entry)
    %CloseButton.pressed.connect(close)

func open() -> void:
    visible = true

func close() -> void:
    visible = false
    closed.emit()

func _on_log_entry(message: String) -> void:
    %LogText.append_text(message + "\n")
    %LogText.scroll_to_line(%LogText.get_line_count())