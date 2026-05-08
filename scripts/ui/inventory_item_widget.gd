extends Control

class_name InventoryItemWidget

var inventory: Inventory
var backpack_index: int = -1

@onready var bg: Panel = $Bg
@onready var icon: TextureRect = $Icon
@onready var empty_text: Label = $EmptyText

func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func bind(inv: Inventory, index: int) -> void:
    inventory = inv
    backpack_index = index
    _refresh()

func _refresh() -> void:
    var item: Resource = _item()
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

func _item() -> Resource:
    if inventory == null or backpack_index < 0:
        return null
    return inventory.peek(Inventory.KIND_BACKPACK, backpack_index)

func _item_icon(item: Resource) -> Texture2D:
    if item is BoundItemResource:
        return (item as BoundItemResource).icon
    if item is AccessoryResource:
        return (item as AccessoryResource).icon
    return null

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        if inventory and _item() != null:
            inventory.toggle_equip(Inventory.KIND_BACKPACK, backpack_index)
        accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
    var item: Resource = _item()
    if item == null:
        return null
    var preview: TextureRect = TextureRect.new()
    preview.texture = _item_icon(item)
    preview.custom_minimum_size = Vector2(48, 48)
    preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    preview.size = Vector2(48, 48)
    set_drag_preview(preview)
    return {"source_kind": Inventory.KIND_BACKPACK, "source_key": backpack_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
    if not (data is Dictionary):
        return false
    if not data.has("source_kind") or not data.has("source_key"):
        return false
    if data["source_kind"] == Inventory.KIND_BACKPACK:
        return false
    if inventory == null:
        return false
    return inventory.peek(data["source_kind"], data["source_key"]) != null

func _drop_data(_at_position: Vector2, data: Variant) -> void:
    if inventory == null:
        return
    inventory.transfer(data["source_kind"], data["source_key"], Inventory.KIND_BACKPACK, null)

func _on_mouse_entered() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel == null:
        return
    var item: Resource = _item()
    if item == null or not item.has_method("to_info_data"):
        return
    panel.show_for(self, item.to_info_data())

func _on_mouse_exited() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.hide_panel()
