extends Control

class_name Enemy

var current_hp: int
var burn_stage: int

@onready var name_label: Label = $Column/NameLabel
@onready var hp_bar: StatBar = $Column/HpBar
@onready var click_area: Button = $ClickArea

@export var enemy_data: EnemyResource

func _ready():
    if (enemy_data != null):
        init(enemy_data)

func init(data: EnemyResource):
    
    
    name_label.text = data.enemy_name
    hp_bar.init(data.max_hp)
    current_hp = data.max_hp
    
    click_area.flat = true
    click_area.pressed.connect(_on_click)

func _on_click():
    EventBus.target_selected.emit(self)

func get_damage(damage: int):
    current_hp -= damage
    hp_bar.update_value(current_hp)
