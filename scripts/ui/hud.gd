extends Control

class_name Hud

@onready var hp_bar: StatBar = $VBoxContainer/HpBar
@onready var heat_bar: StatBar = $VBoxContainer/HeatBar
@onready var overflow_warning: Label = $VBoxContainer/OverflowWarning
@onready var spell_panel: SpellPanel = $VBoxContainer/SpellPanel
@onready var player_status_slot: Control = $VBoxContainer/PlayerStatusSlot

func _ready() -> void:
    EventBus.combat_initialized.connect(_on_combat_initialized)
    EventBus.heat_changed.connect(_on_heat_changed)
    EventBus.player_hp_changed.connect(_on_player_hp_changed)
    EventBus.spellbook_changed.connect(_on_spellbook_changed)

func _on_combat_initialized(max_hp: int, hp: int, max_heat: int, heat: int) -> void:
    hp_bar.init(max_hp, hp)
    heat_bar.init(max_heat, heat)
    overflow_warning.visible = heat > 80
    _host_player_statuses()

func _host_player_statuses() -> void:
    if CombatContext.player == null or CombatContext.player.statuses == null:
        return
    var sc: Node = CombatContext.player.statuses
    if sc.get_parent() == player_status_slot:
        return
    if sc.get_parent():
        sc.reparent(player_status_slot)
    else:
        player_status_slot.add_child(sc)

func _on_heat_changed(heat: int) -> void:
    heat_bar.update_value(heat)
    overflow_warning.visible = heat > 80

func _on_player_hp_changed(hp: int) -> void:
    hp_bar.update_value(hp)

func _on_spellbook_changed(owner_node, spells: Array[SpellResource]) -> void:
    if owner_node != CombatContext.player:
        return
    spell_panel.load_spells(spells)
