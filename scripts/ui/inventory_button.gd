extends Button

class_name InventoryButton

@export var inventory_window_path: NodePath

var _window: InventoryWindow

func _ready() -> void:
    if inventory_window_path != NodePath():
        _window = get_node(inventory_window_path) as InventoryWindow
    pressed.connect(_on_pressed)
    if _window:
        _window.closed.connect(_on_window_closed)
        visible = not _window.visible

func _on_pressed() -> void:
    if _window == null:
        return
    _window.open()
    visible = false

func _on_window_closed() -> void:
    visible = true
