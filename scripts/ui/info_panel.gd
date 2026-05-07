extends Control

class_name InfoPanel

@onready var panel: PanelContainer = %Panel
@onready var icon: TextureRect = %Icon
@onready var name_label: Label = %NameLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var separator: HSeparator = %Separator
@onready var lines_container: VBoxContainer = %LinesContainer

const SCREEN_MARGIN: float = 8.0
const ANCHOR_GAP: float = 8.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    visible = false

func show_for(anchor: Control, data: Dictionary) -> void:
    _populate(data)
    visible = false
    await get_tree().process_frame
    _reposition_near(anchor)
    visible = true

func hide_panel() -> void:
    visible = false

func _populate(data: Dictionary) -> void:
    name_label.text = String(data.get("title", ""))

    var icon_tex: Texture2D = data.get("icon")
    icon.texture = icon_tex
    icon.visible = icon_tex != null

    var subtitle: String = String(data.get("subtitle", ""))
    subtitle_label.text = subtitle
    subtitle_label.visible = subtitle != ""

    var description: String = String(data.get("description", ""))
    description_label.text = description
    description_label.visible = description != ""

    for child in lines_container.get_children():
        child.queue_free()

    var lines: Array = data.get("lines", [])
    for line in lines:
        var row := HBoxContainer.new()
        var label_node := Label.new()
        label_node.text = String(line.get("label", ""))
        label_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var value_node := Label.new()
        value_node.text = String(line.get("value", ""))
        value_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        row.add_child(label_node)
        row.add_child(value_node)
        lines_container.add_child(row)
    lines_container.visible = not lines.is_empty()

    separator.visible = description != "" or not lines.is_empty()

func _reposition_near(anchor: Control) -> void:
    panel.size = panel.get_combined_minimum_size()
    var my_size: Vector2 = panel.size
    var anchor_rect: Rect2 = anchor.get_global_rect()
    var viewport_size: Vector2 = get_viewport_rect().size

    var pos := Vector2(
        anchor_rect.position.x + anchor_rect.size.x + ANCHOR_GAP,
        anchor_rect.position.y
    )

    if pos.x + my_size.x > viewport_size.x - SCREEN_MARGIN:
        pos.x = anchor_rect.position.x - my_size.x - ANCHOR_GAP

    if pos.y + my_size.y > viewport_size.y - SCREEN_MARGIN:
        pos.y = anchor_rect.position.y + anchor_rect.size.y - my_size.y

    pos.x = clamp(pos.x, SCREEN_MARGIN, viewport_size.x - my_size.x - SCREEN_MARGIN)
    pos.y = clamp(pos.y, SCREEN_MARGIN, viewport_size.y - my_size.y - SCREEN_MARGIN)

    global_position = pos