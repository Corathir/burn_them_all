extends Control

class_name SpellButton

var spell_name: String
var heat_cost: int
var spell_resource: SpellResource

var _selected: bool = false
var _hovered: bool = false

signal pressed_spell(spell_res)

@onready var overlay = $Overlay
@onready var click_area: Button = $ClickArea
@onready var cost_label: Label = $CostLabel
@onready var icon: TextureRect = $Icon
@onready var icon_active: TextureRect = $IconActive

func init(spell: SpellResource):
    spell_name = spell.spell_name
    spell_resource = spell
    heat_cost = spell.effective_heat_cost(CombatContext.player)
    cost_label.text = str(heat_cost)
    icon.texture = spell.icon
    icon_active.texture = spell.icon_active
    click_area.pressed.connect(_on_click)
    click_area.mouse_entered.connect(_on_mouse_entered)
    click_area.mouse_exited.connect(_on_mouse_exited)

func set_active(active: bool):
    _selected = active
    _refresh_icon()

func update_disabled_state(current_heat: int):
    var not_enough_heat = current_heat < heat_cost
    overlay.visible = not_enough_heat
    click_area.disabled = not_enough_heat

func _refresh_icon() -> void:
    var active: bool = _selected or _hovered
    icon.visible = not active
    icon_active.visible = active

func _on_click():
    pressed_spell.emit(spell_resource)

func _on_mouse_entered() -> void:
    _hovered = true
    _refresh_icon()
    var panel: InfoPanel = CombatContext.info_panel
    if panel and spell_resource:
        panel.show_for(self, spell_resource.to_info_data(CombatContext.player))

func _on_mouse_exited() -> void:
    _hovered = false
    _refresh_icon()
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.hide_panel()
