# Current task

Task 18 — Spark spell actual effect: call `BurningSystem.ignite(enemy)`.

---

## State

### Done (tasks 1–17)
- Project structure, EventBus with signals
- SpellResource, EnemyResource, .tres test files
- Scenes: EnemySlot, CombatArena, HUD
- Components: StatBar, SpellButton, SpellPanel
- CombatManager: selected_spell, heat spend/gain, turn cycle, enemy phase, overflow damage
- CombatLog scene: listens to `log_entry`, auto-scrolls
- BurningSystem: `ignite`, `advance_all`, `get_stage`, `collect_heat`, stage-change logs
- Full turn cycle: player phase → overflow check → advance burn → enemy phase

### Current code notes
- `EventBus` has `spell_resolved` signal (not in original spec — added during development, keep it)
- `SpellPanel` listens to `spell_resolved` to deselect active button — this is correct
- `Enemy.burn_stage: int` exists but is unused — BurningSystem owns burn state via `burning_targets` dict
- `CombatManager.current_heat` starts at 50 (hardcoded for testing)
- `BurningSystem.ignite()` is never called yet — `burning_targets` is always empty until Task 18

---

## Task 15 — CombatLog scene

Create `scenes/ui/combat_log.tscn`:
- Root: PanelContainer
- Inside: ScrollContainer → RichTextLabel (name it LogText, bbcode_enabled = true)

Create `scripts/ui/combat_log.gd`:
- On ready: connect to `EventBus.log_entry`
- On log_entry: call `append_text()` on RichTextLabel with text + "\n"
- Auto-scroll to bottom after each entry: call `scroll_to_line(get_line_count())` on RichTextLabel

Add CombatLog instance to main scene.

---

## Task 16 — BurningSystem

Create `scripts/combat/burning_system.gd` (extends Node).

Burn stages as enum:
```
enum BurnStage { NONE, KINDLING, BLAZING, FADING, EXTINGUISHED }
```

Data structure: `var burning_targets: Dictionary = {}` — key is Enemy node, value is BurnStage.

Methods:
- `ignite(target: Enemy)` — sets target to KINDLING, emits `EventBus.burn_stage_changed(target)`
- `advance_all()` — called at start of each round, advances every target one stage forward. FADING → EXTINGUISHED → remove from dict. Emit `burn_stage_changed` for each.
- `get_stage(target: Enemy) -> BurnStage` — returns current stage or NONE if not in dict
- `collect_heat(target: Enemy) -> int` — returns Heat amount based on stage (KINDLING=15, BLAZING=30, FADING=10), does NOT advance stage

Stage effects on enemy (used by EnemyAI, not by BurningSystem itself):
- KINDLING: enemy deals 50% damage
- BLAZING: enemy deals 0 damage
- FADING: enemy deals 50% damage

Create `scenes/combat/burning_system.tscn` — single Node with this script.
Add as child of CombatManager in the scene tree.

---

## Task 17 — Full turn cycle in CombatManager

CombatManager currently has no turn structure. Add:

**Player phase:**
- `turn_ended` signal → call `_end_player_turn()`
- `_end_player_turn()`: call `BurningSystem.advance_all()`, then run enemy phase

**Collect Heat spell handling:**
- In `_click_enemy`: check if `selected_spell` is collect_heat (ends_turn == true)
- If yes: get heat from `BurningSystem.collect_heat(enemy)`, call `_gain_heat()`, end turn immediately
- If no: current behavior (spend heat, log, clear selected)

**Enemy phase (simple for now):**
- Each enemy in combat deals damage to player (hardcode player HP = 100 for now)
- Damage is modified by burn stage: KINDLING/FADING = 50% of base damage, BLAZING = 0
- After all enemies act, emit `log_entry` for each attack
- Then start new round (advance burn stages already done in _end_player_turn)

**Overflow:**
- At end of player turn, before enemy phase: if `current_heat > 100`, player takes `current_heat - 100` damage, log it

---

## Next after 17
- Task 18: Spark spell actual effect (calls BurningSystem.ignite)
- Task 19: EnemySlot reacts to burn_stage_changed (shows stage label)
- Task 20: Fan Flames, Scorch spell effects