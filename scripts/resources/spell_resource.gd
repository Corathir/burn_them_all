extends Resource

class_name SpellResource

@export var spell_name: String
@export var heat_cost: int
@export var ends_turn: bool
@export var description: String
@export var target_type: TargetType

enum TargetType {
    SINGLE_ENEMY,
    SINGLE_BURNABLE,
    ALL_BURNING,
    SELF,
    NONE
}
