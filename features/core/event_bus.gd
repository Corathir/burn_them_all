extends Node

signal spell_selected(spell_res: Resource)
signal spell_cast(spell_res: SpellResource)
signal target_selected(enemy)
signal heat_changed(value: int)
signal player_hp_changed(value: int)
signal player_status_changed(status: int, charges: int)
signal turn_ended()
signal combat_finished(result)
signal log_entry(text)
signal state_changed(new_state)
signal spell_resolved()
signal spell_selection_canceled()
signal combat_initialized(max_hp: int, hp: int, max_heat: int, heat: int)

signal status_applied(carrier: Node, status: Node)
signal status_removed(carrier: Node, status: Node)
signal status_stacks_changed(carrier: Node, status: Node, delta: int)
signal turn_started(actor)
signal turn_ended_by(actor)

signal enemy_hover_entered(enemy)
signal enemy_hover_exited(enemy)

signal spells_loaded(spells: Array[SpellResource])
signal spellbook_changed(owner: Node, spells: Array[SpellResource])

signal damage_dealt(info: DamageInfo)
signal spell_cast_resolved(info: SpellCastInfo)
signal spell_canceled(info: SpellCastInfo)

signal bound_slot_equipped(spell_id: StringName, item: Resource)
signal bound_slot_unequipped(spell_id: StringName)
signal accessory_slot_equipped(slot_index: int, accessory: Resource)
signal accessory_slot_unequipped(slot_index: int)

func _ready() -> void:
    EventBus.log_entry.connect(_log_entry)

func _log_entry(text):
    print(text)
