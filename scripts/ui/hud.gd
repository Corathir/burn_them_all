extends Node

class_name Hud

var current_hp: int
var burn_stage: int

@onready var hp_bar: StatBar = $VBoxContainer/HpBar
@onready var heat_bar: StatBar = $VBoxContainer/HeatBar
@onready var overflow_warning: Label = $VBoxContainer/OverflowWarning


func _ready():
    hp_bar.init(100)
    heat_bar.init(200)
    
    EventBus.heat_changed.connect(_heat_changed)

func _heat_changed(heat):
    heat_bar.update_value(heat)
    
    overflow_warning.visible = heat > 80
    
