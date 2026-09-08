extends Control

class_name SpellPanel

@onready var button_container: GridContainer = $VBoxContainer/GridContainer
@onready var end_turn_button: Button = $VBoxContainer/EndTurn

var buttons: Array[SpellButton] = []
var selected_button: SpellButton = null

func _ready() -> void:
    EventBus.heat_changed.connect(_heat_changed)
    EventBus.spell_resolved.connect(deselect)
    end_turn_button.pressed.connect(_end_turn_pressed)

func load_spells(spells: Array[SpellResource]):
    for b in buttons:
        b.queue_free()
    buttons.clear()
    selected_button = null
    for spell in spells:
        var spell_button: SpellButton = preload("res://features/ui/spell_button/spell_button.tscn").instantiate()
        button_container.add_child(spell_button)
        spell_button.init(spell)
        buttons.append(spell_button)
        spell_button.pressed_spell.connect(_on_spell_click)
        
func _on_spell_click(spell: SpellResource):
    if spell.target_type == SpellResource.TargetType.SELF:
        EventBus.spell_cast.emit(spell)
        return

    var clicked_button: SpellButton = null
    for button in buttons:
        if button.spell_resource == spell:
            clicked_button = button
            break

    if clicked_button == selected_button:
        deselect()
        EventBus.spell_selection_canceled.emit()
        return

    if selected_button:
        selected_button.set_active(false)

    selected_button = clicked_button
    selected_button.set_active(true)
    EventBus.spell_cast.emit(spell)

func deselect():
    if selected_button:
        selected_button.set_active(false)
        selected_button = null

func _heat_changed(heat: int):
    for button in buttons:
        button.update_disabled_state(heat)
    if selected_button and heat < selected_button.heat_cost:
        deselect()

func _end_turn_pressed():
    EventBus.turn_ended.emit()
