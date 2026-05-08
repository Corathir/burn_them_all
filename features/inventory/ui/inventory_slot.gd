extends Control

class_name InventorySlot

@export var kind: int = 0
@export var bound_spell_id: StringName = &""
@export var slot_index: int = 0
@export var label_text: String = ""

var inventory: Inventory

@onready var bg: Panel = $Bg
@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label
@onready var empty_text: Label = $EmptyText

func _ready() -> void:
    if label:
        label.text = label_text
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    refresh()

func bind(inv: Inventory) -> void:
    inventory = inv
    if label:
        label.text = label_text
    refresh()

func _key() -> Variant:
    if kind == Inventory.KIND_BOUND:
        return bound_spell_id
    return slot_index

func refresh() -> void:
    if inventory == null:
        if icon:
            icon.visible = false
        if empty_text:
            empty_text.visible = true
        return
    var item: Resource = inventory.peek(kind, _key())
    if item != null:
        if icon:
            icon.visible = true
            icon.texture = _item_icon(item)
        if empty_text:
            empty_text.visible = false
    else:
        if icon:
            icon.visible = false
            icon.texture = null
        if empty_text:
            empty_text.visible = true

func _item_icon(item: Resource) -> Texture2D:
    if item is BoundItemResource:
        return (item as BoundItemResource).icon
    if item is AccessoryResource:
        return (item as AccessoryResource).icon
    return null

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        if inventory:
            inventory.toggle_equip(kind, _key())
        accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
    if inventory == null:
        return null
    var item: Resource = inventory.peek(kind, _key())
    if item == null:
        return null
    var preview: TextureRect = TextureRect.new()
    preview.texture = _item_icon(item)
    preview.custom_minimum_size = Vector2(48, 48)
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.size = Vector2(48, 48)
    set_drag_preview(preview)
    return {"source_kind": kind, "source_key": _key()}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if not (data is Dictionary):
        return false
    if not data.has("source_kind") or not data.has("source_key"):
        return false
    if inventory == null:
        return false
    var src_item: Resource = inventory.peek(data["source_kind"], data["source_key"])
    if src_item == null:
        return false
    return inventory.is_compatible(kind, _key(), src_item)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    if inventory == null:
        return
    inventory.transfer(data["source_kind"], data["source_key"], kind, _key())

func _on_mouse_entered() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel == null or inventory == null:
        return
    var item: Resource = inventory.peek(kind, _key())
    if item == null or not item.has_method("to_info_data"):
        return
    panel.show_for(self, item.to_info_data())

func _on_mouse_exited() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.hide_panel()
