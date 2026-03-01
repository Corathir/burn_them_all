extends Node

class_name Hud

var current_hp: int
var burn_stage: int

@onready var hp_label: Label = $VBoxContainer/HPContainer/HPBar/HPLabel
@onready var hp_bar: ProgressBar = $VBoxContainer/HPContainer/HPBar
@onready var heat_label: Label = $VBoxContainer/HeatContainer/HeatBar/HeatLabel
@onready var heat_bar: ProgressBar = $VBoxContainer/HeatContainer/HeatBar
@onready var overflow_warning: Label = $VBoxContainer/OverflowWarning


func _ready():
    hp_bar.min_value = 0
    hp_bar.max_value = 100
    hp_label.text = str(100)
    heat_bar.min_value = 0
    heat_bar.max_value = 200
    heat_label.text = str(200)
    
    EventBus.heat_changed.connect(_heat_changed)

func _heat_changed(heat):
    heat_bar.value = heat
    heat_label.text = str(heat)
    
    if (heat > 80):
        overflow_warning.visible = true
    
