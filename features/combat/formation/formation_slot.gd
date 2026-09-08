extends Resource

class_name FormationSlot

@export var position: Vector2 = Vector2.ZERO
@export var row: int = 0
## Position within the row, used to find left/right neighbors. Not derived
## from `position.x` so formations can offset rows without breaking adjacency.
@export var column: int = 0
