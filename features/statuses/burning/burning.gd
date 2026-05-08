extends StatusEffect

class_name BurningStatus

enum Stage { SMOLDERING, KINDLING, BLAZING, FADING }

const STAGE_TEXTURES: Dictionary = {
    Stage.SMOLDERING: preload("res://features/statuses/burning/smoldering.svg"),
    Stage.KINDLING:   preload("res://features/statuses/burning/kindling.svg"),
    Stage.BLAZING:    preload("res://features/statuses/burning/blazing.svg"),
    Stage.FADING:     preload("res://features/statuses/burning/fading.svg"),
}

const COLLECT_COEFFICIENTS: Dictionary = {
    Stage.SMOLDERING: 0.0,
    Stage.KINDLING: 0.5,
    Stage.BLAZING: 1.5,
    Stage.FADING: 1.0,
}

const STAGE_NAMES: Dictionary = {
    Stage.SMOLDERING: "Smoldering",
    Stage.KINDLING: "Kindling",
    Stage.BLAZING: "Blazing",
    Stage.FADING: "Fading",
}

var stage: Stage = Stage.SMOLDERING
var stored_reward: int = 0

@onready var icon: TextureRect = $Icon
@onready var reward_label: Label = $RewardLabel

func _init() -> void:
    id = &"burning"
    display_name = "Burning"
    stack_mode = StackMode.UNIQUE

func on_apply() -> void:
    stored_reward = stacks
    stacks = 1
    _update_visual()
    EventBus.log_entry.emit(_host_name() + " is now Smoldering (+" + str(stored_reward) + " stored)")

func on_stacks_changed(delta: int) -> void:
    if stage == Stage.SMOLDERING:
        stored_reward += delta
        _update_visual()
        EventBus.log_entry.emit(_host_name() + " smolder fed (+" + str(delta) + ", total " + str(stored_reward) + ")")
    else:
        EventBus.log_entry.emit(_host_name() + " is past smoldering — no fuel added")

func on_turn_start() -> void:
    match stage:
        Stage.SMOLDERING:
            _set_stage(Stage.KINDLING)
        Stage.KINDLING:
            _set_stage(Stage.BLAZING)
        Stage.BLAZING:
            _set_stage(Stage.FADING)
        Stage.FADING:
            (host as Combatant).statuses.remove(id)

func calculate_collect_value() -> int:
    var coeff: float = COLLECT_COEFFICIENTS.get(stage, 0.0)
    return int(stored_reward * coeff)

func to_info_data() -> Dictionary:
    var data: Dictionary = super.to_info_data()
    data["icon"] = STAGE_TEXTURES.get(stage)
    data["description"] = "Burns the target. Cycles through stages each turn and weakens its attacks."
    data["lines"] = [
        {"label": "Stage", "value": STAGE_NAMES.get(stage, "")},
        {"label": "Stored fuel", "value": str(stored_reward)},
        {"label": "Collect coefficient", "value": str(COLLECT_COEFFICIENTS.get(stage, 0.0))},
    ]
    return data

func modify_outgoing_damage(info: DamageInfo) -> void:
    if info.type != DamageInfo.Type.ATTACK:
        return
    match stage:
        Stage.KINDLING, Stage.FADING:
            info.amount = int(info.amount * 0.5)
        Stage.BLAZING:
            info.amount = 0
            info.canceled = true

func _set_stage(new_stage: Stage) -> void:
    stage = new_stage
    _update_visual()
    EventBus.log_entry.emit(_host_name() + " is now " + STAGE_NAMES.get(stage, ""))

func _update_visual() -> void:
    if icon:
        icon.texture = STAGE_TEXTURES.get(stage, null)
    if reward_label:
        reward_label.text = str(stored_reward)

func _host_name() -> String:
    if host and host is Combatant and (host as Combatant).display_name != "":
        return (host as Combatant).display_name
    return "Target"
