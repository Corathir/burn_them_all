extends Button

class_name ArenaIcon

func _ready() -> void:
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.show_for(self, _build_data())

func _on_mouse_exited() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.hide_panel()

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