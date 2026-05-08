extends ScrollContainer

class_name InventoryBackpackDrop

var inventory: Inventory

func bind(inv: Inventory) -> void:
    inventory = inv

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
