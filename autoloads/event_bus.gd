extends Node

#class_name EventBus

signal spell_selected(spell_res: Resource)
signal spell_cast(spell_res: Resource)
signal target_selected(enemy: Enemy)
signal heat_changed(value: int)
signal burn_stage_changed(target)
signal turn_ended()
signal combat_finished(result)
signal log_entry(text)
signal state_changed(new_state)
signal spell_resolved()
signal combat_initialized(max_hp: int, hp: int, max_heat: int, heat: int)

func _ready() -> void:
    EventBus.log_entry.connect(_log_entry)

func _log_entry(text):
    print(text)
