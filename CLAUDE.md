# burn_them_all — CLAUDE.md

Turn-based tile dungeon crawler. Single character (Pyromancer). Godot 4.6.1, GDScript.
Repo: github.com/Corathir/burn_them_all

Before writing any code, read `.claude/lessons.md`.
Before starting work, read `.claude/tasks.md` to understand current state.

---

## Project conventions

- snake_case for file names, PascalCase for node names
- Unique node access via `%NodeName`
- All signals are declared in `autoloads/event_bus.gd` (global bus)
- Local signals (within a scene) are declared on the node itself, not in EventBus
- Custom Resources live in `scripts/resources/`, data files in `data/`
- No `@onready` in Resource classes — Resources are not nodes

---

## Architecture rules

**Strict separation: Data / Logic / Display**

- `scripts/resources/` — pure data, no logic, no node references
- `scripts/combat/` — game logic only, no UI calls, no `$Node` access
- `scripts/ui/` — display only: reads signals, updates visuals, emits user input signals

**Two-phase spell flow (do not break this)**
```
SpellButton.pressed_spell  →  SpellPanel._on_spell_click  →  EventBus.spell_cast
EventBus.spell_cast        →  CombatManager._spell_cast
```
`spell_cast` carries `SpellResource`, not `SpellButton`.
`CombatManager` stores `selected_spell: SpellResource`.

**Spell target flow**
```
Enemy.ClickArea.pressed  →  EventBus.target_selected(enemy: Enemy)
EventBus.target_selected →  CombatManager._on_target_selected
```
`CombatManager` applies the spell only if `selected_spell != null`.

**BurningSystem is centralized**
Not a component on Enemy. One node manages all burning targets.
`BurningSystem` advances stages at the start of each round, not per-entity.

**UI does not own game state**
UI scripts (`scripts/ui/`) only react to EventBus signals — they don't hold HP, Heat, or burn stage values.
`hud.gd` does not load spells either. Spells are loaded by `CombatManager` and sent to `SpellPanel` via `EventBus.spells_loaded`.

**Enemy is a visual entity, not a logical one**
`scripts/entities/enemy.gd` holds display state only (`current_hp`, `burn_stage` for UI).
Damage calculation and burn stage transitions live in `CombatManager` / `BurningSystem`, not in `Enemy`.

---

## Core mechanic — Heat

- Range: 0–100 (soft cap). Overflow = Heat > 100 → (Heat - 100) damage at end of turn
- Heat is both action points and danger resource — this duality is intentional
- `Collect Heat` is free but ends the turn immediately (`ends_turn = true` on SpellResource)
- Player can cast multiple spells per turn as long as Heat allows

## Core mechanic — Burning cycle

```
None → Kindling → Blazing → Fading → Extinguished → None
```
Stage transitions happen at start of each round (in BurningSystem, not in Enemy).
Stage effects on enemy: Kindling/Fading = -50% damage, Blazing = 0 damage (can't attack).
Heat returned on Collect: Kindling=75%, Blazing=150%, Fading=50% of Spark base cost (20).

---

## Signal reference (EventBus)

| Signal | Payload | Direction |
|---|---|---|
| `spell_selected` | `SpellResource` | SpellButton → SpellPanel |
| `spell_cast` | `SpellResource` | SpellPanel → CombatManager |
| `target_selected` | `Enemy` | EnemySlot → CombatManager |
| `heat_changed` | `int` | CombatManager → HUD |
| `burn_stage_changed` | `target` | BurningSystem → EnemySlot |
| `turn_ended` | — | SpellPanel → CombatManager |
| `combat_finished` | `result` | CombatManager → GameManager |
| `log_entry` | `String` | anywhere → CombatLog |

---

## File structure (current)

```
autoloads/event_bus.gd
scripts/
  combat/combat_manager.gd
  entities/enemy.gd
  resources/spell_resource.gd, enemy_resource.gd
  ui/hud.gd, spell_panel.gd, spell_button.gd, stat_bar.gd
data/spells/*.tres, data/enemies/*.tres
scenes/combat/*, scenes/ui/*
```

Planned (not yet implemented):
```
scripts/combat/burning_system.gd
scripts/combat/heat_system.gd
scripts/combat/spell_executor.gd
scripts/combat/enemy_ai.gd
scripts/entities/env_object.gd
```

---

## Node type rule

When describing scene structure, always specify the node type for every element.
Example: `HPBar (ProgressBar)`, not just `HPBar`.

---

## What I do not want

- Do not rewrite working code unless asked
- Do not add features beyond the current task
- Do not leave placeholder comments like `# TODO` or `# add logic here`
- Do not suggest switching to C# or changing the engine version

