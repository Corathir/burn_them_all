extends Control

class_name SpellPanel

const spell_button_scene: String = "res://scenes/ui/spell_button.tscn"

@onready var end_turn_button: Button = $EndTurn

var buttons = Array[SpellButton]

func _ready() -> void:
    EventBus.heat_changed.connect(_heat_changed)
    end_turn_button.pressed.connect(_end_turn_pressed)

func load_spells(spells: Array[SpellResource]):
    for spell in spells:
        var spell_button = preload(self.spell_button_scene).instantiate()
        spell_button.init(spell)
        self.add_child(spell_button)
        buttons.add(spell_button)
        spell_button.pressed_spell.connect(_on_spell_click)
        
func _on_spell_click(spell: SpellResource):
    EventBus.spell_cast.emit(spell)

func _heat_changed(heat: int):
    for button in buttons:
        button.update_disabled_state(heat)

func _end_turn_pressed():
    EventBus.turn_ended.emit()
