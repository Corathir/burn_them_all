# lessons.md

Accumulated rules from corrections. Read before writing any code.

---

## GDScript

- `@onready` is only valid in nodes (extends Node or its subclasses). Never use it in Resource classes.
- When accessing a child node by unique name (`%Name`), the node must have "Unique Name in Owner" enabled in the scene — verify this before writing the accessor.
- `class_name` declarations are global. Do not reuse names across different scripts.

## Signals

- `EventBus.spell_cast` carries `SpellResource`, not `SpellButton`. `CombatManager.selected_spell` is typed `SpellResource`.
- Do not emit a signal with a type that differs from its declaration in event_bus.gd.
- Local signals (e.g. `pressed_spell` on SpellButton) are declared on the node script, not in EventBus.

## Architecture

- `hud.gd` does not load spells. Spell loading is CombatManager's responsibility.
- UI scripts do not hold game state (HP values, Heat values, burn stage). They only react to signals.
- `Enemy` (scripts/entities/enemy.gd) is a visual scene node — it holds display state (current_hp, burn_stage for UI). Game logic (damage calculation, burn transitions) lives in CombatManager / BurningSystem.
- BurningSystem is a single centralized node, not a component attached to each enemy.

## Scenes

- Every node in a described scene structure must have its type specified (e.g. `HPBar (ProgressBar)`).
- When instantiating a scene via `preload().instantiate()`, add it to the tree before calling `init()` on it if `init` references `@onready` vars.
