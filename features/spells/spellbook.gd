extends Node

class_name Spellbook

var spells: Array[SpellResource] = []

func add_spell(spell: SpellResource) -> void:
    if spell == null or spells.has(spell):
        return
    spells.append(spell)
    EventBus.spellbook_changed.emit(get_parent(), spells)

func remove_spell(spell: SpellResource) -> void:
    if not spells.has(spell):
        return
    spells.erase(spell)
    EventBus.spellbook_changed.emit(get_parent(), spells)

func has_spell(spell_id: StringName) -> bool:
    for s in spells:
        if s.id == spell_id:
            return true
    return false
