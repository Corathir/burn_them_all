extends Node

class_name BurningSystem

enum BurnStage { NONE, SMOLDERING, KINDLING, BLAZING, FADING }

const COLLECT_COEFFICIENTS: Dictionary = {
    BurnStage.SMOLDERING: 0.0,
    BurnStage.KINDLING: 0.5,
    BurnStage.BLAZING: 1.5,
    BurnStage.FADING: 1.0,
}

var burning_targets: Dictionary = {}
var stored_rewards: Dictionary = {}

func ignite(target: Enemy, reward: int) -> void:
    var stage = get_stage(target)
    match stage:
        BurnStage.NONE:
            burning_targets[target] = BurnStage.SMOLDERING
            stored_rewards[target] = reward
            _emit_changed(target)
            EventBus.log_entry.emit(target.enemy_data.enemy_name + " is now Smoldering (+" + str(reward) + " stored)")
        BurnStage.SMOLDERING:
            stored_rewards[target] += reward
            _emit_changed(target)
            EventBus.log_entry.emit(target.enemy_data.enemy_name + " smolder fed (+" + str(reward) + ", total " + str(stored_rewards[target]) + ")")
        _:
            EventBus.log_entry.emit(target.enemy_data.enemy_name + " is past smoldering — no fuel added")

func advance_all() -> void:
    var targets_to_remove: Array = []

    for target in burning_targets.keys():
        var current_stage = burning_targets[target]

        match current_stage:
            BurnStage.SMOLDERING:
                burning_targets[target] = BurnStage.KINDLING
                _emit_changed(target)
                EventBus.log_entry.emit(target.enemy_data.enemy_name + " is now Kindling")
            BurnStage.KINDLING:
                burning_targets[target] = BurnStage.BLAZING
                _emit_changed(target)
                EventBus.log_entry.emit(target.enemy_data.enemy_name + " is now Blazing")
            BurnStage.BLAZING:
                burning_targets[target] = BurnStage.FADING
                _emit_changed(target)
                EventBus.log_entry.emit(target.enemy_data.enemy_name + " is now Fading")
            BurnStage.FADING:
                targets_to_remove.append(target)
                EventBus.log_entry.emit(target.enemy_data.enemy_name + " fire is gone")

    for target in targets_to_remove:
        burning_targets.erase(target)
        stored_rewards.erase(target)
        _emit_changed(target)

func _emit_changed(target: Enemy) -> void:
    var stage: int = burning_targets.get(target, BurnStage.NONE)
    var reward: int = stored_rewards.get(target, 0)
    EventBus.burn_stage_changed.emit(target, stage, reward)

func get_stage(target: Enemy) -> BurnStage:
    return burning_targets.get(target, BurnStage.NONE)

func collect_heat(target: Enemy) -> int:
    var stage = get_stage(target)
    var coefficient: float = COLLECT_COEFFICIENTS.get(stage, 0.0)
    var stored: int = stored_rewards.get(target, 0)
    var heat: int = int(stored * coefficient)
    if heat > 0:
        burning_targets.erase(target)
        stored_rewards.erase(target)
        _emit_changed(target)
    return heat
