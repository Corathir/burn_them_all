extends StatusEffect

class_name BurningStatus

enum Stage { SMOLDERING, KINDLING, BLAZING, FADING }

const STAGE_TEXTURES: Dictionary = {
    Stage.SMOLDERING: preload("res://features/statuses/burning/smoldering.svg"),
    Stage.KINDLING:   preload("res://features/statuses/burning/kindling.svg"),
    Stage.BLAZING:    preload("res://features/statuses/burning/blazing.svg"),
    Stage.FADING:     preload("res://features/statuses/burning/fading.svg"),
}

## Heat multipliers for collecting at each stage (Smoldering is unreachable — blocked by can_target).
const COLLECT_HEAT_MULTIPLIERS: Dictionary = {
    Stage.KINDLING: 0.5,
    Stage.BLAZING: 2.0,
    Stage.FADING: 1.0,
}

const FADING_INCOMING_DAMAGE_MULT: float = 1.5

const STAGE_NAMES: Dictionary = {
    Stage.SMOLDERING: "Smoldering",
    Stage.KINDLING: "Kindling",
    Stage.BLAZING: "Blazing",
    Stage.FADING: "Fading",
}

const STUN_SCENE: PackedScene = preload("res://features/statuses/stun/stun_status.tscn")
const BURNING_SCENE_PATH: String = "res://features/statuses/burning/burning.tscn"

var stage: Stage = Stage.SMOLDERING
var stored_reward: int = 0
var _hover_preview: bool = false
var _collected_during_fading: bool = false

@onready var icon: TextureRect = $Icon
@onready var reward_label: Label = $RewardLabel

func _init() -> void:
    id = &"burning"
    display_name = "Burning"
    stack_mode = StackMode.UNIQUE
    negative = true

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
            if not _collected_during_fading:
                (host as Combatant).statuses.apply(STUN_SCENE, 1)
                EventBus.log_entry.emit(_host_name() + "'s fire burns out and stuns them")
            (host as Combatant).statuses.remove(id)

## On death, the host's stored fuel is split evenly across its live formation
## neighbors, applying (or feeding, if already Smoldering) Burning on each.
func on_death() -> void:
    var enemy: Enemy = host as Enemy
    if enemy == null or stored_reward <= 0:
        return
    var neighbors: Array[Enemy] = enemy.get_neighbors()
    if neighbors.is_empty():
        return
    var share: int = stored_reward / neighbors.size()
    if share <= 0:
        return
    var burning_scene: PackedScene = load(BURNING_SCENE_PATH) as PackedScene
    if burning_scene == null:
        return
    for neighbor in neighbors:
        neighbor.statuses.apply(burning_scene, share)
    EventBus.log_entry.emit(_host_name() + "'s death spreads " + str(share) + " Smoldering fuel to each neighbor")

func calculate_collect_heat_value() -> int:
    if not COLLECT_HEAT_MULTIPLIERS.has(stage):
        return 0
    return int(stored_reward * COLLECT_HEAT_MULTIPLIERS[stage])

## Kindling additionally ruptures the target for the full stored amount.
func calculate_collect_damage_value() -> int:
    return stored_reward if stage == Stage.KINDLING else 0

## Called by CollectHeatEffect once targeting has already been validated
## (stage != SMOLDERING). Each stage has a distinct payoff.
func resolve_collect(caster: Combatant, target: Combatant) -> void:
    if stage == Stage.KINDLING:
        var dmg: int = calculate_collect_damage_value()
        caster.deal_damage(target, dmg, DamageInfo.Type.PURE, &"collect_heat")
        EventBus.log_entry.emit("Collect Heat ruptures " + _host_name() + " for " + str(dmg) + " damage")
    if stage == Stage.FADING:
        _collected_during_fading = true
    _grant_heat(caster, calculate_collect_heat_value())
    target.statuses.remove(&"burning")

func _grant_heat(caster: Combatant, heat: int) -> void:
    if caster.has_method("gain_heat"):
        caster.gain_heat(heat)
    EventBus.log_entry.emit("Collect Heat → " + _host_name() + " (+" + str(heat) + " Heat)")

func to_info_data() -> Dictionary:
    var data: Dictionary = super.to_info_data()
    data["icon"] = STAGE_TEXTURES.get(stage)
    data["description"] = "Burns the target. Cycles through stages each turn."
    var lines: Array = [
        {"label": "Stage", "value": STAGE_NAMES.get(stage, "")},
        {"label": "Stored fuel", "value": str(stored_reward)},
        _collect_preview_line(),
    ]
    if stage == Stage.FADING:
        lines.append({"label": "Incoming damage", "value": "+" + str(int((FADING_INCOMING_DAMAGE_MULT - 1.0) * 100)) + "%"})
    data["lines"] = lines
    return data

func _collect_preview_line() -> Dictionary:
    match stage:
        Stage.KINDLING:
            return {"label": "Collect", "value": str(calculate_collect_damage_value()) + " damage, +" + str(calculate_collect_heat_value()) + " Heat"}
        Stage.BLAZING, Stage.FADING:
            return {"label": "Collect", "value": "+" + str(calculate_collect_heat_value()) + " Heat"}
        _:
            return {"label": "Collect", "value": "unavailable"}

## Fading amplifies incoming damage for as long as it's still active —
## regardless of how it eventually gets removed (collect or natural expiry).
func modify_incoming_damage(info: DamageInfo) -> void:
    if info.canceled or stage != Stage.FADING:
        return
    info.amount = int(info.amount * FADING_INCOMING_DAMAGE_MULT)

func _set_stage(new_stage: Stage) -> void:
    stage = new_stage
    _update_visual()
    EventBus.log_entry.emit(_host_name() + " is now " + STAGE_NAMES.get(stage, ""))

func on_hover_enter(_caster: Combatant, spell: SpellResource) -> void:
    if spell == null or not _has_collect_heat_effect(spell):
        return
    _hover_preview = true
    if reward_label:
        var preview: int = calculate_collect_damage_value() if stage == Stage.KINDLING else calculate_collect_heat_value()
        reward_label.text = str(preview)
    if icon:
        icon.modulate = Color(1.35, 1.25, 0.85)
    _set_highlighted(true)

func on_hover_exit() -> void:
    _set_highlighted(false)
    if not _hover_preview:
        return
    _hover_preview = false
    _update_visual()

func _has_collect_heat_effect(spell: SpellResource) -> bool:
    for effect in spell.effects:
        if effect is CollectHeatEffect:
            return true
    return false

func _update_visual() -> void:
    if icon:
        icon.texture = STAGE_TEXTURES.get(stage, null)
        icon.modulate = Color.WHITE
    if reward_label:
        reward_label.text = str(stored_reward)

func _host_name() -> String:
    if host and host is Combatant and (host as Combatant).display_name != "":
        return (host as Combatant).display_name
    return "Target"
