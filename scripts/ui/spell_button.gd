extends Control

class_name SpellButton

var spell_name: String
var heat_cost: int
var spell_resourse: SpellResource

signal pressed_spell(spell_res)

@onready var overlay = $Overlay
@onready var click_area: Button = $ClickArea

func init(spell: SpellResource):
    spell_name = spell.spell_name
    heat_cost = spell.heat_cost
    click_area.pressed.connect(_on_click)

func update_disabled_state(current_heat: int):
    overlay.visible = current_heat > heat_cost

func _on_click():
    pressed_spell.emit(spell_resourse)
    pass
