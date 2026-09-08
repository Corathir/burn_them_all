extends Resource

class_name FormationSlot

@export var position: Vector2 = Vector2.ZERO
@export var row: int = 0
## Position within the row, used to find neighbors. Not derived from
## `position.x` so formations can offset rows without breaking adjacency.
## Same-row neighbors differ by 1 (e.g. 0, 1, 2 for a row of 3).
## A row with fewer slots that's interleaved between another row's slots
## (e.g. a 2-slot row behind a 3-slot row) uses half-steps (0.5, 1.5) so
## each of its slots lines up between — and is adjacent to — the two slots
## of the other row it sits behind/in front of (column diff of 0.5).
@export var column: float = 0.0
