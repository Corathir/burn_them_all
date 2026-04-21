extends Node

enum BurnStage { NONE, KINDLING, BLAZING, FADING, EXTINGUISHED }

var burning_targets: Dictionary = {}

func ignite(target: Enemy) -> void:
    burning_targets[target] = BurnStage.KINDLING
    EventBus.burn_stage_changed.emit(target)
    EventBus.log_entry.emit(target.enemy_data.enemy_name + " is now Kindling")

func advance_all() -> void:
    var targets_to_remove: Array = []

    for target in burning_targets.keys():
        var current_stage = burning_targets[target]

        match current_stage:
            BurnStage.KINDLING:
                burning_targets[target] = BurnStage.BLAZING
                EventBus.burn_stage_changed.emit(target)
                EventBus.log_entry.emit(target.enemy_data.enemy_name + " is now Blazing")
            BurnStage.BLAZING:
                burning_targets[target] = BurnStage.FADING
                EventBus.burn_stage_changed.emit(target)
                EventBus.log_entry.emit(target.enemy_data.enemy_name + " is now Fading")
            BurnStage.FADING:
                burning_targets[target] = BurnStage.EXTINGUISHED
                EventBus.burn_stage_changed.emit(target)
                EventBus.log_entry.emit(target.enemy_data.enemy_name + " fire is Extinguished")
            BurnStage.EXTINGUISHED:
                targets_to_remove.append(target)
                EventBus.burn_stage_changed.emit(target)

    for target in targets_to_remove:
        burning_targets.erase(target)

func get_stage(target: Enemy) -> BurnStage:
    return burning_targets.get(target, BurnStage.NONE)

func collect_heat(target: Enemy) -> int:
    var stage = get_stage(target)

    match stage:
        BurnStage.KINDLING:
            return 15
        BurnStage.BLAZING:
            return 30
        BurnStage.FADING:
            return 10
        _:
            return 0
