extends Combatant

class_name Player

@export var max_heat: int = 200
@export var initial_heat: int = 50
@export var basic_spells: Array[SpellResource] = []

var heat: int

@onready var inventory: Inventory = %Inventory

func _ready() -> void:
    super._ready()
    heat = initial_heat
    CombatContext.player = self
    add_to_group("player_carrier")
    for spell in basic_spells:
        spellbook.add_spell(spell)
    _emit_initial_state.call_deferred()

func _emit_initial_state() -> void:
    EventBus.combat_initialized.emit(max_hp, hp, max_heat, heat)
    EventBus.spellbook_changed.emit(self, spellbook.spells)

func _try_pay_cost(spell: SpellResource) -> bool:
    if heat < spell.heat_cost:
        return false
    heat -= spell.heat_cost
    EventBus.heat_changed.emit(heat)
    return true

func gain_heat(amount: int) -> void:
    heat += amount
    EventBus.heat_changed.emit(heat)

func spend_heat(amount: int) -> void:
    heat -= amount
    EventBus.heat_changed.emit(heat)

func apply_raw_damage(amount: int) -> void:
    super.apply_raw_damage(amount)
    EventBus.player_hp_changed.emit(hp)
