extends Control

class_name Combatant

@export var max_hp: int = 30
@export var display_name: String

var hp: int

@onready var statuses: StatusContainer = %StatusContainer
@onready var spellbook: Spellbook = %Spellbook

func _ready() -> void:
    hp = max_hp

func deal_damage(target: Combatant, base: int, type: int, ability_id: StringName = &"") -> DamageInfo:
    var info := DamageInfo.new()
    info.amount = base
    info.type = type
    info.source = self
    info.target = target
    info.ability_id = ability_id

    statuses.process_outgoing_damage(info)
    if CombatContext.arena:
        CombatContext.arena.statuses.process_outgoing_damage(info)
    target.statuses.process_incoming_damage(info)
    if CombatContext.arena:
        CombatContext.arena.statuses.process_incoming_damage(info)

    if info.canceled:
        return info
    target.apply_raw_damage(info.amount)
    EventBus.damage_dealt.emit(info)

    for s in statuses.get_children():
        if s is StatusEffect:
            s.on_damage_dealt(info)
    for s in target.statuses.get_children():
        if s is StatusEffect:
            s.on_damage_taken(info)
    return info

func preview_spell(spell: SpellResource) -> SpellCastInfo:
    var info := SpellCastInfo.new()
    info.spell = spell
    info.caster = self
    info.target = null
    info.effects = spell.effects.duplicate()
    if statuses:
        statuses.process_pre_cast(info)
    if CombatContext.arena and not info.canceled:
        CombatContext.arena.statuses.process_pre_cast(info)
    return info

func cast(spell: SpellResource, target: Combatant) -> bool:
    var info := SpellCastInfo.new()
    info.spell = spell
    info.caster = self
    info.target = target
    info.effects = spell.effects.duplicate()

    statuses.process_pre_cast(info)
    if CombatContext.arena:
        CombatContext.arena.statuses.process_pre_cast(info)
    if target:
        target.statuses.process_pre_cast_incoming(info)

    if info.canceled:
        EventBus.spell_canceled.emit(info)
        return false

    if not _try_pay_cost(info):
        return false

    for effect in info.effects:
        effect.execute(info)

    statuses.process_post_cast(info)
    if CombatContext.arena:
        CombatContext.arena.statuses.process_post_cast(info)
    EventBus.spell_cast_resolved.emit(info)
    return true

func apply_raw_damage(amount: int) -> void:
    hp = max(0, hp - amount)

func _try_pay_cost(_info: SpellCastInfo) -> bool:
    return true
