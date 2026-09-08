extends Control

class_name CursorOverlay

const POINTER_TEXTURE: Texture2D = preload("res://features/ui/cursor/cursor.svg")
const POINTER_ENEMY_TEXTURE: Texture2D = preload("res://features/ui/cursor/cursor_red.svg")

const SPELL_ICON_OFFSET: Vector2 = Vector2(20.0, 20.0)

@onready var pointer: TextureRect = %Pointer
@onready var spell_icon: TextureRect = %SpellIcon

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
    pointer.texture = POINTER_TEXTURE
    spell_icon.visible = false
    EventBus.spell_selected.connect(_on_spell_selected)
    EventBus.spell_resolved.connect(_clear_spell_icon)
    EventBus.spell_selection_canceled.connect(_clear_spell_icon)

func _process(_delta: float) -> void:
    var mouse_pos: Vector2 = get_viewport().get_mouse_position()
    pointer.global_position = mouse_pos
    pointer.texture = POINTER_ENEMY_TEXTURE if _is_over_enemy_sprite(mouse_pos) else POINTER_TEXTURE
    if spell_icon.visible:
        spell_icon.global_position = mouse_pos + SPELL_ICON_OFFSET

func _is_over_enemy_sprite(global_point: Vector2) -> bool:
    for enemy in CombatContext.enemies:
        if enemy is Enemy and is_instance_valid(enemy) and (enemy as Enemy).is_point_over_sprite(global_point):
            return true
    return false

func _on_spell_selected(spell: SpellResource) -> void:
    spell_icon.texture = spell.icon
    spell_icon.visible = spell.icon != null

func _clear_spell_icon() -> void:
    spell_icon.visible = false
