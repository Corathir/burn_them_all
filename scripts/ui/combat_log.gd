extends PanelContainer

func _ready() -> void:
	EventBus.log_entry.connect(_on_log_entry)

func _on_log_entry(message: String) -> void:
	%LogText.append_text(message + "\n")
	%LogText.scroll_to_line(%LogText.get_line_count())