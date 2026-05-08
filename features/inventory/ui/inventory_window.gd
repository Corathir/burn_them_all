extends Control

class_name InventoryWindow

signal closed

var _inventory: Inventory

@onready var left_hand: InventorySlot = %LeftHandSlot
@onready var right_hand: InventorySlot = %RightHandSlot
@onready var head: InventorySlot = %HeadSlot
@onready var accessory_slots: Array[InventorySlot] = [
    %AccessorySlot0,
    %AccessorySlot1,
    %AccessorySlot2,
    %AccessorySlot3,
]
@onready var backpack_scroll: InventoryBackpackDrop = %BackpackScroll
@onready var backpack_grid: GridContainer = %BackpackGrid
@onready var close_button: Button = %CloseButton

const ITEM_WIDGET_SCENE: PackedScene = preload("res://features/inventory/ui/inventory_item_widget.tscn")
const MIN_BACKPACK_CELLS: int = 20
const BACKPACK_TRAILING_EMPTY: int = 4

func _ready() -> void:
    close_button.pressed.connect(close)
    left_hand.kind = Inventory.KIND_BOUND
    left_hand.bound_spell_id = &"collect_heat"
    left_hand.label_text = "Left"
    right_hand.kind = Inventory.KIND_BOUND
    right_hand.bound_spell_id = &"spark"
    right_hand.label_text = "Right"
    head.kind = Inventory.KIND_BOUND
    head.bound_spell_id = &"heat_touch"
    head.label_text = "Head"
    for i in accessory_slots.size():
        var s: InventorySlot = accessory_slots[i]
        s.kind = Inventory.KIND_ACCESSORY
        s.slot_index = i
        s.label_text = "Acc " + str(i + 1)
    _bind.call_deferred()

func _bind() -> void:
    if CombatContext.player == null:
        return
    _inventory = CombatContext.player.inventory
    if _inventory == null:
        return
    _inventory.changed.connect(refresh)
    left_hand.bind(_inventory)
    right_hand.bind(_inventory)
    head.bind(_inventory)
    for s in accessory_slots:
        s.bind(_inventory)
    backpack_scroll.bind(_inventory)
    refresh()

func open() -> void:
    visible = true

func close() -> void:
    visible = false
    closed.emit()

func refresh() -> void:
    if _inventory == null:
        return
    left_hand.refresh()
    right_hand.refresh()
    head.refresh()
    for s in accessory_slots:
        s.refresh()
    _rebuild_backpack()

func _rebuild_backpack() -> void:
    for child in backpack_grid.get_children():
        child.queue_free()
    var item_count: int = _inventory.backpack.size()
    var total_cells: int = max(MIN_BACKPACK_CELLS, item_count + BACKPACK_TRAILING_EMPTY)
    for i in total_cells:
        var widget: InventoryItemWidget = ITEM_WIDGET_SCENE.instantiate()
        backpack_grid.add_child(widget)
        var index: int = i if i < item_count else -1
        widget.bind(_inventory, index)
