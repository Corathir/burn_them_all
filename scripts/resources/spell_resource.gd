extends Resource

class_name SpellResource

@export var spell_name: String
@export var heat_cost: int
@export var heat_reward: int = 0
@export var ends_turn: bool
@export var description: String
@export var target_type: TargetType
@export var icon: Texture2D
@export var icon_active: Texture2D

enum TargetType {
    SINGLE_ENEMY,
    SINGLE_BURNABLE,
    ALL_BURNING,
    SELF,
    NONE
}
