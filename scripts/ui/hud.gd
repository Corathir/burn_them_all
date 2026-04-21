extends Node

class_name Hud

var current_hp: int
var burn_stage: int

@onready var hp_bar: StatBar = $VBoxContainer/HpBar
@onready var heat_bar: StatBar = $VBoxContainer/HeatBar
@onready var overflow_warning: Label = $VBoxContainer/OverflowWarning
@onready var spell_panel: SpellPanel = $VBoxContainer/SpellPanel


func _ready():
    spell_panel.load_spells([
        preload("res://data/spells/collect_heat.tres"),
        preload("res://data/spells/heat_touch.tres"),
        preload("res://data/spells/spark.tres")
    ])

    EventBus.combat_initialized.connect(_on_combat_initialized)
    EventBus.heat_changed.connect(_heat_changed)

func _on_combat_initialized(max_hp: int, hp: int, max_heat: int, heat: int):
    hp_bar.init(max_hp, hp)
    heat_bar.init(max_heat, heat)
    overflow_warning.visible = heat > 80

func _heat_changed(heat):
    heat_bar.update_value(heat)

    overflow_warning.visible = heat > 80
    
