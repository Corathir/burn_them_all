extends Control

class_name BurnStatusIcon

const STAGE_TEXTURES: Dictionary = {
    BurningSystem.BurnStage.SMOLDERING: preload("res://assets/burning_stages/smoldering.svg"),
    BurningSystem.BurnStage.KINDLING:   preload("res://assets/burning_stages/kindling.svg"),
    BurningSystem.BurnStage.BLAZING:    preload("res://assets/burning_stages/blazing.svg"),
    BurningSystem.BurnStage.FADING:     preload("res://assets/burning_stages/fading.svg"),
}

@onready var icon: TextureRect = $Icon
@onready var reward_label: Label = $RewardLabel

func _ready() -> void:
    visible = false

func set_stage(stage: int, reward: int) -> void:
    if STAGE_TEXTURES.has(stage):
        icon.texture = STAGE_TEXTURES[stage]
        reward_label.text = str(reward)
        visible = true
    else:
        visible = false