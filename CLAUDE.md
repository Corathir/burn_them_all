# burn_them_all — CLAUDE.md

Turn-based tile dungeon crawler. Single character (Pyromancer). Godot 4.6.1, GDScript.
Repo: github.com/Corathir/burn_them_all

Before writing any code, read `.claude/lessons.md`.

---

## Project conventions

- snake_case for file names, PascalCase for node names
- 4-space indentation in all GDScript files (no tabs)
- Unique node access via `%NodeName`
- Global signals are declared in `autoloads/event_bus.gd`
- Local signals (within a scene) are declared on the node itself, not in EventBus
- Custom Resources live in `scripts/resources/`, data files in `data/`
- No `@onready` in Resource classes — Resources are not nodes
- `class_name` declarations are global; do not reuse names across scripts

---

## Architecture rules

**Strict separation: Data / Logic / Display**

- `scripts/resources/` — pure data, no logic, no node references
- `scripts/combat/`, `scripts/entities/`, `scripts/statuses/` — game logic, no UI calls, no `$Node` access into UI
- `scripts/ui/` — display only: reads signals, updates visuals, emits user input signals

**Combatant hierarchy (composition over inheritance)**
`Combatant extends Control` is the base class for any actor that fights.
- `Player extends Combatant` — owns Heat, Inventory, basic_spells
- `Enemy extends Combatant` — owns EnemyResource, click target, AI
Every Combatant has a `%StatusContainer` and `%Spellbook` child.
Combat is delegated to `Combatant.cast(spell, target)` and `Combatant.deal_damage(target, amount, type, ability_id)`. Do not bypass these — statuses hook into them.

**CombatContext autoload (`autoloads/combat_context.gd`)**
Global access point: `CombatContext.player`, `CombatContext.enemies`, `CombatContext.arena`.
Combatants register/unregister themselves on `_ready` / `tree_exiting`. Read from this instead of looking up nodes by path.

**Two-phase spell flow (do not break this)**
```
SpellButton.pressed_spell  →  SpellPanel._on_spell_click  →  EventBus.spell_cast(SpellResource)
EventBus.spell_cast        →  CombatManager._on_spell_cast
```
- SELF-targeted spells: CombatManager calls `player.cast(spell, null)` immediately.
- Enemy-targeted spells: CombatManager stores `selected_spell` and waits for `target_selected`.

**Spell target flow**
```
Enemy.ClickArea.pressed  →  EventBus.target_selected(enemy)
EventBus.target_selected →  CombatManager._on_target_selected
```
CombatManager applies the spell only if `selected_spell != null`, then emits `spell_resolved` to clear UI selection.

**Effect-based spells (data-driven)**
`SpellResource.effects` is an `Array` of `SpellEffectResource` objects. Each effect implements `execute(info: SpellCastInfo)`.
Existing effects in `scripts/resources/effects/`:
- `DealDamageEffect` — `caster.deal_damage(target, amount, damage_type, spell.id)`
- `ApplyStatusEffect` — applies a status scene to caster (`apply_to_self`) or target
- `CollectHeatEffect` — reads `BurningStatus` on target, awards Heat, removes status
- `IgniteEffect` — applies the burning scene to target with `reward` stacks
Add new spell behavior by writing a new `SpellEffectResource` subclass — do **not** branch on `spell.id` in CombatManager.

**Status effects (composable, priority-sorted)**
A `StatusEffect extends Control` is instanced as a child of a `StatusContainer`. Each status is a `.tscn` so it can carry icon/label nodes. Lifecycle hooks (override what you need):
- `on_apply`, `on_remove`, `on_stacks_changed(delta)`
- `on_turn_start`, `on_turn_end`
- `modify_outgoing_damage(info)`, `modify_incoming_damage(info)` — can mutate or cancel `DamageInfo`
- `on_damage_dealt(info)`, `on_damage_taken(info)`
- `modify_pre_cast(info)`, `modify_pre_cast_incoming(info)`, `modify_post_cast(info)` — can cancel a cast
- `intercept_status_change(req)` — can cancel apply/remove/stack changes

Statuses are processed in descending `priority` order. `stack_mode`: DURATION, INTENSITY, REFRESH, UNIQUE.

**Arena owns global statuses**
`Arena` is a node next to `CombatManager`. It holds `%StatusContainer` and an `ArenaResource`.
On `enter_battle`: applies `battle_start_effects` to filtered combatants and `permanent_statuses` to the arena itself.
The arena’s status container also intercepts every combatant’s damage/cast pipeline (see `Combatant.cast` / `Combatant.deal_damage`).

**Pipeline objects (RefCounted, mutated by handlers)**
- `DamageInfo` — `amount, type, source, target, ability_id, canceled`. `Type` enum: `ATTACK, SPELL, BURNING, OVERFLOW, PURE`.
- `SpellCastInfo` — `spell, caster, target, effects, canceled, extra_data`.
- `StatusChangeRequest` — `kind (APPLY/REMOVE/MODIFY_STACKS), host, status_id, status_scene, stacks, canceled`.

**Spellbook**
Every Combatant has a `Spellbook` child with `spells: Array[SpellResource]`. Use `add_spell` / `remove_spell` — these emit `spellbook_changed`. The HUD listens for `spellbook_changed` on the player and rebuilds the spell panel.

**Inventory (Player only)**
`Inventory` lives under Player and manages two slot kinds:
- Bound slots — a `BoundItemResource` modifies a specific spell by applying a `modifier_status` to the player
- Accessory slots — an `AccessoryResource` can grant a spell and apply passive statuses
Equipping/unequipping always goes through `Inventory` so status refs are tracked.

**UI does not own game state**
`scripts/ui/` only reacts to EventBus signals. No HP, Heat, or status values are stored in UI scripts.
`hud.gd` does not load spells — it receives them via `EventBus.spellbook_changed` for the player.

---

## Core mechanic — Heat

- Range: 0–`Player.max_heat` (currently 200). Soft cap at 100.
- End of player turn: if `heat > 100`, player takes `(heat - 100)` raw damage as overflow.
- Heat is both action points and danger resource — this duality is intentional.
- `Collect Heat` is free but ends the turn (`ends_turn = true` on SpellResource).
- Player can cast multiple spells per turn while Heat allows.

## Core mechanic — Burning cycle

`scripts/statuses/burning.gd` (`BurningStatus extends StatusEffect`). UNIQUE stack mode; `stacks` is repurposed as `stored_reward` (set on apply; further applications add to it while still smoldering).

```
Smoldering → Kindling → Blazing → Fading → (removed)
```

Stage transitions happen in `on_turn_start` (the host’s turn).

Effects on outgoing ATTACK damage from the burning host:
- Kindling, Fading: damage × 0.5
- Blazing: damage = 0, attack canceled
- Smoldering: no effect

Heat returned by `CollectHeatEffect` = `stored_reward * coefficient`:
- Smoldering 0.0 · Kindling 0.5 · Blazing 1.5 · Fading 1.0

Adding more fuel (re-applying burning) only works during Smoldering — past that, fuel is rejected.

---

## Signal reference (EventBus)

| Signal | Payload | Direction |
|---|---|---|
| `spell_selected` | `Resource` | (legacy, available) |
| `spell_cast` | `SpellResource` | SpellPanel → CombatManager |
| `spell_resolved` | — | CombatManager → SpellPanel |
| `spell_canceled` | `SpellCastInfo` | Combatant.cast → listeners |
| `spell_cast_resolved` | `SpellCastInfo` | Combatant.cast → listeners |
| `target_selected` | `Enemy` | Enemy.ClickArea → CombatManager |
| `turn_ended` | — | SpellPanel → CombatManager |
| `turn_started` | `actor` | CombatManager → StatusContainer/listeners |
| `turn_ended_by` | `actor` | CombatManager → StatusContainer/listeners |
| `heat_changed` | `int` | Player → HUD |
| `player_hp_changed` | `int` | Player → HUD |
| `player_status_changed` | `int, int` | (status, charges) — reserved |
| `combat_initialized` | `max_hp, hp, max_heat, heat` | Player → HUD |
| `combat_finished` | `result` | CombatManager → GameManager |
| `damage_outgoing` / `damage_incoming` | `Node, DamageContext` | reserved (legacy) |
| `damage_dealt` | `DamageInfo` | Combatant.deal_damage |
| `status_applied` / `status_removed` | `carrier, status` | StatusContainer |
| `status_stacks_changed` | `carrier, status, delta` | StatusContainer |
| `spells_loaded` | `Array[SpellResource]` | reserved |
| `spellbook_changed` | `owner, Array[SpellResource]` | Spellbook → HUD |
| `bound_slot_equipped` / `bound_slot_unequipped` | `spell_id[, item]` | Inventory |
| `accessory_slot_equipped` / `accessory_slot_unequipped` | `slot_index[, accessory]` | Inventory |
| `state_changed` | `new_state` | reserved |
| `log_entry` | `String` | anywhere → CombatLog |

---

## File structure (current)

```
autoloads/
  event_bus.gd
  combat_context.gd
scripts/
  combat/
    combat_manager.gd
    arena.gd
    spellbook.gd
    status_container.gd
    status_effect.gd
    inventory.gd
    damage_context.gd            (legacy, unused by current pipeline)
    pipeline/
      damage_info.gd
      spell_cast_info.gd
      status_change_request.gd
  entities/
    combatant.gd                 (base class)
    player.gd
    enemy.gd
  statuses/
    burning.gd
    shield.gd
  resources/
    spell_resource.gd
    enemy_resource.gd
    arena_resource.gd
    arena_battle_start_entry.gd
    bound_item_resource.gd
    accessory_resource.gd
    effects/
      spell_effect_resource.gd   (base)
      deal_damage_effect.gd
      apply_status_effect.gd
      collect_heat_effect.gd
      ignite_effect.gd
  ui/
    hud.gd, spell_panel.gd, spell_button.gd, stat_bar.gd, combat_log.gd
data/
  spells/{spark, collect_heat, heat_touch, shield}.tres
  enemies/skeleton.tres
scenes/
  combat/{combat_arena, combat_manager, arena, enemy_slot, inventory}.tscn
  entities/player.tscn
  statuses/{burning, shield}.tscn
  ui/{hud, spell_panel, spell_button, stat_bar, combat_log}.tscn
```

Planned (not yet implemented):
```
scripts/combat/heat_system.gd
scripts/combat/enemy_ai.gd
scripts/entities/env_object.gd
```

---

## Node type rule

When describing scene structure, always specify the node type for every element.
Example: `HpBar (StatBar)`, not just `HpBar`.

---

## What I do not want

- Do not rewrite working code unless asked
- Do not add features beyond the current task
- Do not leave placeholder comments like `# TODO` or `# add logic here`
- Do not branch on `spell.id` in CombatManager — write a new `SpellEffectResource` instead
- Do not put logical state (HP, Heat, burn stage) in UI scripts
- Do not bypass `Combatant.cast` / `Combatant.deal_damage` — statuses depend on those pipelines
- Do not suggest switching to C# or changing the engine version