extends Control

class_name Enemy

var current_hp: int
var burn_stage: int

@onready var name_label: Label = $Column/NameLabel
@onready var hp_bar: ProgressBar = $Column/HPBar
@onready var hp_label: Label = $Column/HPBar/Label
@onready var click_area: Button = $ClickArea

@export var enemy_data: EnemyResource

func _ready():
    print(enemy_data != null)
    if (enemy_data != null):
        init(enemy_data)

func init(data: EnemyResource):
    name_label.text = data.enemy_name
    hp_bar.min_value = 0
    hp_bar.max_value = data.max_hp
    hp_bar.value = data.max_hp
    current_hp = data.max_hp
    hp_label.text = str(data.max_hp)
    
    click_area.flat = true
    click_area.pressed.connect(_on_click)

func _on_click():
    EventBus.target_selected.emit(self)

func get_damage(damage: int):
    current_hp -= damage
    hp_bar.value = current_hp
    hp_label.text = str(current_hp)
