extends Button

class_name ArenaIcon

@export var info_panel_path: NodePath

var _info_panel: InfoPanel

func _ready() -> void:
    if info_panel_path != NodePath():
        _info_panel = get_node(info_panel_path) as InfoPanel
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
    if _info_panel == null:
        return
    _info_panel.show_for(self, _build_data())

func _on_mouse_exited() -> void:
    if _info_panel:
        _info_panel.hide_panel()

func _build_data() -> Dictionary:
    var data: Dictionary = {
        "title": "Arena",
        "subtitle": "Battlefield",
        "description": "",
        "lines": [],
    }
    var arena: Arena = CombatContext.arena as Arena
    if arena == null:
        data["description"] = "No active arena."
        return data
    var def: ArenaResource = arena.def
    if def == null or (def.battle_start_effects.is_empty() and def.permanent_statuses.is_empty()):
        if def != null and def.display_name != "":
            data["title"] = def.display_name
        data["description"] = "Plain arena. No special effects."
        return data
    if def.display_name != "":
        data["title"] = def.display_name
    var lines: Array = []
    if not def.battle_start_effects.is_empty():
        lines.append({
            "label": "Battle start effects",
            "value": str(def.battle_start_effects.size()),
        })
    if not def.permanent_statuses.is_empty():
        lines.append({
            "label": "Permanent statuses",
            "value": str(def.permanent_statuses.size()),
        })
    data["lines"] = lines
    return data