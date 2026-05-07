extends Node

class_name Inventory

@onready var bound_slots: Node = $BoundSlots
@onready var accessory_slots: Node = $AccessorySlots

var _bound_status_refs: Dictionary = {}
var _accessory_status_refs: Dictionary = {}
var _accessory_spell_refs: Dictionary = {}

func _player() -> Player:
    return get_parent() as Player

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
    EventBus.bound_slot_equipped.emit(spell_id, item)
    return true

func unequip_bound(spell_id: StringName) -> void:
    var ref = _bound_status_refs.get(spell_id, null)
    if ref:
        var p: Player = _player()
        if p:
            p.statuses.remove(ref.id)
        _bound_status_refs.erase(spell_id)
    EventBus.bound_slot_unequipped.emit(spell_id)

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
    EventBus.accessory_slot_equipped.emit(slot_index, accessory)
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
    EventBus.accessory_slot_unequipped.emit(slot_index)
