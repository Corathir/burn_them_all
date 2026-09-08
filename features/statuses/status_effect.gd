extends Control

class_name StatusEffect

enum StackMode { DURATION, INTENSITY, REFRESH, UNIQUE }

@export var id: StringName
@export var display_name: String
@export var stack_mode: StackMode = StackMode.INTENSITY
@export var priority: int = 0
@export var negative: bool = false

var stacks: int = 1
var host: Node

var _hover_highlighted: bool = false

func _ready() -> void:
    for child in get_children():
        if child is Control:
            (child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func to_info_data() -> Dictionary:
    var lines: Array = []
    if stacks > 0:
        lines.append({"label": "Stacks", "value": str(stacks)})
    return {
        "title": display_name,
        "subtitle": "Status",
        "description": "",
        "lines": lines,
    }

func _on_mouse_entered() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.show_for(self, to_info_data())

func _on_mouse_exited() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.hide_panel()

func on_apply() -> void:
    pass

func on_remove() -> void:
    pass

func on_stacks_changed(_delta: int) -> void:
    pass

func on_turn_start() -> void:
    pass

func on_turn_end() -> void:
    pass

## Override to make the host skip its next action (see StunStatus). The
## caller is responsible for removing the status once it consumes the skip.
func blocks_turn() -> bool:
    return false

## Fires once, when the host's hp drops from >0 to <=0 (see BurningStatus).
func on_death() -> void:
    pass

func modify_outgoing_damage(_info: DamageInfo) -> void:
    pass

func modify_incoming_damage(_info: DamageInfo) -> void:
    pass

func on_damage_dealt(_info: DamageInfo) -> void:
    pass

func on_damage_taken(_info: DamageInfo) -> void:
    pass

func modify_pre_cast(_info: SpellCastInfo) -> void:
    pass

func modify_pre_cast_incoming(_info: SpellCastInfo) -> void:
    pass

func modify_post_cast(_info: SpellCastInfo) -> void:
    pass

func intercept_status_change(_req: StatusChangeRequest) -> void:
    pass

## Called when the cursor enters the host's hover area (e.g. the enemy's
## click region). `spell` is whatever spell is currently pending a target
## (null if none). Override `_reacts_to_hover` to opt into the default
## highlight, or override this directly for a custom preview (see BurningStatus).
func on_hover_enter(caster: Combatant, spell: SpellResource) -> void:
    if _reacts_to_hover(caster, spell):
        _set_highlighted(true)

func on_hover_exit() -> void:
    _set_highlighted(false)

## Override to opt into the generic hover highlight (see ArmorStatus).
func _reacts_to_hover(_caster: Combatant, _spell: SpellResource) -> bool:
    return false

func _set_highlighted(value: bool) -> void:
    if _hover_highlighted == value:
        return
    _hover_highlighted = value
    pivot_offset = size / 2.0
    scale = Vector2.ONE * 1.25 if value else Vector2.ONE
    modulate = Color(1.35, 1.25, 0.85) if value else Color.WHITE
