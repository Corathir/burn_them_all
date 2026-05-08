extends Node

class_name Inventory

signal changed()

const ACCESSORY_SLOT_COUNT: int = 4

const KIND_BOUND: int = 0
const KIND_ACCESSORY: int = 1
const KIND_BACKPACK: int = 2

@export var initial_bound: Array[Resource] = []
@export var initial_accessories: Array[Resource] = []
@export var initial_backpack: Array[Resource] = []

var bound_items: Dictionary = {}
var accessory_items: Dictionary = {}
var backpack: Array = []

var _bound_status_refs: Dictionary = {}
var _accessory_status_refs: Dictionary = {}
var _accessory_spell_refs: Dictionary = {}

func _player() -> Player:
    return get_parent() as Player

func apply_initial_loadout() -> void:
    for item in initial_bound:
        if item is BoundItemResource:
            equip_bound(item.bound_spell_id, item)
    for i in min(initial_accessories.size(), ACCESSORY_SLOT_COUNT):
        var acc: Variant = initial_accessories[i]
        if acc is AccessoryResource:
            equip_accessory(i, acc)
    for item in initial_backpack:
        if item != null:
            backpack.append(item)
    changed.emit()

func equip_bound(spell_id: StringName, item: BoundItemResource) -> bool:
    if item == null or item.bound_spell_id != spell_id:
        return false
    var p: Player = _player()
    if p == null:
        return false
    unequip_bound(spell_id)
    if item.modifier_status:
        var status: StatusEffect = p.statuses.apply(item.modifier_status, 1)
        _bound_status_refs[spell_id] = status
    bound_items[spell_id] = item
    EventBus.bound_slot_equipped.emit(spell_id, item)
    changed.emit()
    return true

func unequip_bound(spell_id: StringName) -> void:
    var ref: Variant = _bound_status_refs.get(spell_id, null)
    if ref:
        var p: Player = _player()
        if p:
            p.statuses.remove(ref.id)
        _bound_status_refs.erase(spell_id)
    var had: bool = bound_items.has(spell_id)
    bound_items.erase(spell_id)
    if had:
        EventBus.bound_slot_unequipped.emit(spell_id)
        changed.emit()

func equip_accessory(slot_index: int, accessory: AccessoryResource) -> bool:
    if accessory == null:
        return false
    var p: Player = _player()
    if p == null:
        return false
    unequip_accessory(slot_index)
    if accessory.granted_spell:
        p.spellbook.add_spell(accessory.granted_spell)
        _accessory_spell_refs[slot_index] = accessory.granted_spell
    var applied: Array = []
    for status_scene in accessory.passive_statuses:
        var status: StatusEffect = p.statuses.apply(status_scene, 1)
        if status:
            applied.append(status.id)
    _accessory_status_refs[slot_index] = applied
    accessory_items[slot_index] = accessory
    EventBus.accessory_slot_equipped.emit(slot_index, accessory)
    changed.emit()
    return true

func unequip_accessory(slot_index: int) -> void:
    var p: Player = _player()
    if p == null:
        return
    var spell: SpellResource = _accessory_spell_refs.get(slot_index, null)
    if spell:
        p.spellbook.remove_spell(spell)
        _accessory_spell_refs.erase(slot_index)
    var ids: Array = _accessory_status_refs.get(slot_index, [])
    for status_id in ids:
        p.statuses.remove(status_id)
    _accessory_status_refs.erase(slot_index)
    var had: bool = accessory_items.has(slot_index)
    accessory_items.erase(slot_index)
    if had:
        EventBus.accessory_slot_unequipped.emit(slot_index)
        changed.emit()

func peek(kind: int, key: Variant) -> Resource:
    match kind:
        KIND_BOUND:
            return bound_items.get(key, null)
        KIND_ACCESSORY:
            return accessory_items.get(key, null)
        KIND_BACKPACK:
            if key is int and key >= 0 and key < backpack.size():
                return backpack[key]
            return null
    return null

func is_compatible(kind: int, key: Variant, item: Resource) -> bool:
    if item == null:
        return false
    match kind:
        KIND_BOUND:
            if not (item is BoundItemResource):
                return false
            return (item as BoundItemResource).bound_spell_id == key
        KIND_ACCESSORY:
            return item is AccessoryResource
        KIND_BACKPACK:
            return true
    return false

func transfer(from_kind: int, from_key: Variant, to_kind: int, to_key: Variant) -> bool:
    if from_kind == to_kind and from_key == to_key:
        return false
    if from_kind == KIND_BACKPACK and to_kind == KIND_BACKPACK:
        return false

    var from_item: Resource = peek(from_kind, from_key)
    if from_item == null:
        return false
    var to_item: Resource = peek(to_kind, to_key)

    if not is_compatible(to_kind, to_key, from_item):
        return false
    if to_item != null and from_kind != KIND_BACKPACK and not is_compatible(from_kind, from_key, to_item):
        return false

    _detach(from_kind, from_key)
    if to_item != null:
        _detach(to_kind, to_key)

    _attach(to_kind, to_key, from_item)
    if to_item != null:
        if from_kind == KIND_BACKPACK:
            _attach(KIND_BACKPACK, null, to_item)
        else:
            _attach(from_kind, from_key, to_item)
    return true

func toggle_equip(kind: int, key: Variant) -> bool:
    if kind == KIND_BACKPACK:
        var item: Resource = peek(KIND_BACKPACK, key)
        if item == null:
            return false
        if item is BoundItemResource:
            var sid: StringName = (item as BoundItemResource).bound_spell_id
            if not bound_items.has(sid):
                return transfer(KIND_BACKPACK, key, KIND_BOUND, sid)
            return transfer(KIND_BACKPACK, key, KIND_BOUND, sid)
        if item is AccessoryResource:
            for i in range(ACCESSORY_SLOT_COUNT):
                if not accessory_items.has(i):
                    return transfer(KIND_BACKPACK, key, KIND_ACCESSORY, i)
            return false
        return false
    return transfer(kind, key, KIND_BACKPACK, null)

func _detach(kind: int, key: Variant) -> Resource:
    match kind:
        KIND_BOUND:
            var item: Resource = bound_items.get(key, null)
            if item:
                unequip_bound(key)
            return item
        KIND_ACCESSORY:
            var item: Resource = accessory_items.get(key, null)
            if item:
                unequip_accessory(key)
            return item
        KIND_BACKPACK:
            if key is int and key >= 0 and key < backpack.size():
                var item: Resource = backpack[key]
                backpack.remove_at(key)
                changed.emit()
                return item
            return null
    return null

func _attach(kind: int, key: Variant, item: Resource) -> bool:
    match kind:
        KIND_BOUND:
            return equip_bound(key, item as BoundItemResource)
        KIND_ACCESSORY:
            return equip_accessory(key, item as AccessoryResource)
        KIND_BACKPACK:
            backpack.append(item)
            changed.emit()
            return true
    return false
