# lessons.md

Accumulated rules from corrections. Read before writing any code.

---

## GDScript

- When accessing a child node by unique name (`%Name`), the node must have "Unique Name in Owner" enabled in the scene — verify this before writing the accessor.
- `class_name` declarations are global. Do not reuse names across different scripts.

## Signals

- Do not emit a signal with a type that differs from its declaration in event_bus.gd.

## Scenes

- When instantiating a scene via `preload().instantiate()`, add it to the tree before calling `init()` on it if `init` references `@onready` vars.