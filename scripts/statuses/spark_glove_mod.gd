extends StatusEffect

class_name SparkGloveMod

const COST_REDUCTION: int = 10

func _init() -> void:
    id = &"mod_spark_glove"
    display_name = "Spark Glove"
    stack_mode = StackMode.UNIQUE
    priority = 0

func modify_pre_cast(info: SpellCastInfo) -> void:
    if info.spell == null or info.spell.id != &"spark":
        return
    var current: int = info.extra_data.get("heat_cost_delta", 0)
    info.extra_data["heat_cost_delta"] = current - COST_REDUCTION
