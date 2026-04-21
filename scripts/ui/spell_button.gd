extends Control

class_name SpellButton

var spell_name: String
var heat_cost: int
var spell_resource: SpellResource

signal pressed_spell(spell_res)

@onready var overlay = $Overlay
@onready var click_area: Button = $ClickArea
@onready var name_label = $Column/NameLabel
@onready var cost_label: Label = $Column/CostLabel
@onready var icon: TextureRect = $Icon
@onready var icon_active: TextureRect = $IconActive

func init(spell: SpellResource):
    name_label.text = spell.spell_name
    cost_label.text = str(spell.heat_cost)
    spell_name = spell.spell_name
    heat_cost = spell.heat_cost
    spell_resource = spell
    icon.texture = spell.icon
    icon_active.texture = spell.icon_active
    click_area.pressed.connect(_on_click)

func set_active(active: bool):
    icon.visible = !active
    icon_active.visible = active

func update_disabled_state(current_heat: int):
    var not_enough_heat = current_heat < heat_cost
    overlay.visible = not_enough_heat
    click_area.disabled = not_enough_heat

func _on_click():
    pressed_spell.emit(spell_resource)
