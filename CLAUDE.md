# burn_them_all — CLAUDE.md

Turn-based dungeon crawler. Single character (Pyromancer). Godot 4.6.1, GDScript.
Repo: github.com/Corathir/burn_them_all
Detailed reference: `ARCHITECTURE.md`. Lessons / past mistakes: `.claude/lessons.md` — read before writing code.

---

## Conventions

- `snake_case` files, `PascalCase` nodes, 4-space indent (no tabs).
- `%NodeName` access requires "Unique Name in Owner" on the node.
- `class_name` is global — never reuse names.
- Project is **vertical-sliced** under `features/`: one feature = one folder. Base classes live one level up. No separate `scripts/`, `scenes/`, `data/`, `assets/` folders. No `@onready` in `Resource`.
- Global signals + autoloads in `features/core/`. Local signals stay on the node.

## Layered separation

| Layer   | Folder                                                       | Allowed                              |
|---------|--------------------------------------------------------------|--------------------------------------|
| Data    | `*Resource.gd` + `.tres` (inside each feature folder)        | Values, scene refs                   |
| Logic   | `features/{core, combat, combatants, statuses, inventory}/`  | Game state, no UI calls              |
| Display | `features/ui/`, `features/inventory/ui/`                     | Subscribes to signals; no game state |

UI never owns truth. `hud.gd` doesn't load spells — it reacts to `spellbook_changed`.

---

## Combatant pipeline

```
Combatant (Control)
├── Player    — Heat, Inventory, basic_spells
└── Enemy     — EnemyResource, ClickArea, AI
```

Every Combatant has `%StatusContainer` (HBox) and `%Spellbook` (Node) children.

`CombatContext` autoload registers `player`, `enemies: Array`, `arena`. Read from this — never look up by path.

**Two methods carry every interaction; do not bypass them:**

- `Combatant.cast(spell, target) -> bool`
- `Combatant.deal_damage(target, amount, type, ability_id) -> DamageInfo`

Both run statuses (caster → arena → target → arena) over their pipeline objects, then commit.

### Spell flow

```
SpellButton  → SpellPanel  → EventBus.spell_cast(SpellResource)
                            → CombatManager._on_spell_cast
                              ├── SELF      → player.cast(spell, null)
                              └── targeted  → store selected_spell, wait

Enemy.ClickArea → EventBus.target_selected(enemy)
                → CombatManager._on_target_selected → player.cast(spell, enemy)
                → EventBus.spell_resolved (clears UI selection)
```

Inside `cast()`: `process_pre_cast` → `_try_pay_cost` (Player charges Heat) → `effect.execute(info)` for each effect → `process_post_cast` → emit `spell_cast_resolved`.

### Effect-based spells (data-driven)

`SpellResource.effects: Array` holds `SpellEffectResource` objects, each with `execute(info: SpellCastInfo)`.

| Effect              | Action                                                     |
|---------------------|------------------------------------------------------------|
| `DealDamageEffect`  | `caster.deal_damage(target, amount, type, spell.id)`       |
| `ApplyStatusEffect` | applies `status_scene` to target (or caster if `apply_to_self`) |
| `BurningEffect`     | applies `burning.tscn` with `reward` stacks                |
| `CollectHeatEffect` | reads `BurningStatus`, awards Heat, removes status         |

Add new behavior by writing a new `SpellEffectResource` subclass — **do not** branch on `spell.id` in `CombatManager`.

### Spell preview (for UI)

`Combatant.preview_spell(spell) -> SpellCastInfo` runs `process_pre_cast` only — no payment, no execute. UI uses this to show post-modifier values.

- `SpellResource.effective_heat_cost(caster)` → `max(0, heat_cost + delta)`. `SpellButton` shows this on the icon (no parens).
- `SpellResource.to_info_data(caster)` → renders `Heat cost 20 (-10)` and `Damage 0 (+10)` in the tooltip (base + delta in parens; just the base if delta is 0).

> **Constraint:** `modify_pre_cast` hooks must mutate only `info.extra_data` / `info.effects` — no logging, no HP/Heat changes, no status applies. Otherwise preview becomes a real cast.

---

## Status effects

`StatusEffect extends Control` — instanced as a child of a `StatusContainer`. Each status is a `.tscn` so it carries icon/label nodes.

**Lifecycle hooks (override what you need):**

- `on_apply`, `on_remove`, `on_stacks_changed(delta)`
- `on_turn_start`, `on_turn_end` — fire on host's turn only
- `modify_outgoing_damage(info)` / `modify_incoming_damage(info)` — mutate or cancel `DamageInfo`
- `on_damage_dealt(info)` / `on_damage_taken(info)`
- `modify_pre_cast(info)` / `modify_pre_cast_incoming(info)` / `modify_post_cast(info)` — can cancel a cast
- `intercept_status_change(req)` — can cancel apply/remove/stack changes

Statuses run in descending `priority`. `stack_mode`: `DURATION`, `INTENSITY`, `REFRESH`, `UNIQUE`. `negative: bool` marks debuffs — `StatusContainer.apply()` copies it from the probe into `StatusChangeRequest.negative` so interceptors (e.g. `ShieldStatus`) can react.

**Existing statuses:**

- `BurningStatus` — 4-stage burn cycle (see Mechanics). `negative = true`.
- `ShieldStatus` — cancels the next negative status applied to host, consumes a stack. Uses `intercept_status_change`.
- `ArmorStatus` — `modify_incoming_damage`: absorbs damage and grants the player Heat 1:1. Auto-removes on host's `on_turn_start`.
- `CollectGloveMod` / `SparkGloveMod` / `HeatTouchHelmMod` / `MaxHeatMod` — invisible item-modifier statuses, live under `features/statuses/item_mods/` (see Inventory).

### Pipeline objects (RefCounted)

- `DamageInfo` — `amount, type, source, target, ability_id, canceled`. Type: `ATTACK | SPELL | BURNING | OVERFLOW | PURE`.
- `SpellCastInfo` — `spell, caster, target, effects, canceled, extra_data`.
- `StatusChangeRequest` — `kind (APPLY/REMOVE/MODIFY_STACKS), host, status_id, status_scene, stacks, negative, canceled`.

### Arena

`Arena` lives next to `CombatManager`, owns its own `%StatusContainer` and an `ArenaResource`. On `enter_battle()` it applies `battle_start_effects` to filtered combatants and `permanent_statuses` to itself. The arena's status container intercepts every combatant's damage/cast pipeline.

### EnemyFormation (spawn API)

`EnemyFormation` (`features/combat/formation/enemy_formation.gd`) places enemies according to a `FormationResource`. Runtime spawn API:

```
populate(new_formation: FormationResource, entries: Array)
# entry = {"slot_index": int, "enemy_data": EnemyResource}
```

`populate()` clears existing Enemy children, instances `enemy_slot.tscn` per entry, sets fields, runs `_layout()`. Called at boot from `Room._ready` using the Room's exported `enemies` array.

### Room (encounter scene)

`Room` (`features/combat/room/room.{gd,tscn}`) is the encounter container instanced in `main.tscn`. It exports:

- `arena_def: ArenaResource` — assigned to `CombatContext.arena.def` on `_ready`.
- `formation: FormationResource` — passed to its `EnemyFormation` child.
- `enemies: Array[RoomEnemyEntry]` — each entry has `slot_index` and `enemy_data`.

A future room generator builds Rooms by setting these three fields. `CombatManager._start_combat` runs deferred, so by then Room has populated the formation and assigned the arena def.

> Don't add enemies via node-overrides from `main.tscn` (`[node parent="Room/EnemyFormation"]`). Godot drops such overrides on re-save when any reference temporarily fails to resolve. Add enemies in the same scene where `EnemyFormation` lives, or via `populate()`.

---

## Inventory (Player only)

`Inventory` (under Player) has three storages:

- **Bound slots** — `BoundItemResource` with `bound_spell_id` modifies a specific spell by applying its `modifier_status` to the player. Slot key = the spell id (`&"collect_heat"`, `&"spark"`, `&"heat_touch"`).
- **Accessory slots** (4) — `AccessoryResource` may add a spell (`granted_spell`) and/or apply `passive_statuses`.
- **Backpack** — unbounded `Array` of inactive items; key = index.

Equipping always goes through `Inventory.equip_*` / `unequip_*` so status refs are tracked. Single transfer API: `Inventory.transfer(from_kind, from_key, to_kind, to_key)` handles move, swap (occupied compatible slot), and backpack overflow. `toggle_equip(kind, key)` is the RMB shortcut.

Compatibility: bound slots accept only matching `BoundItemResource`; accessory slots accept any `AccessoryResource`; backpack accepts anything.

**Refresh signal chain:** `Inventory.changed` → `Player._on_inventory_changed` → re-emits `EventBus.spellbook_changed` → `SpellPanel` rebuilds buttons → effective costs and tooltips refresh.

**UI:** `InventoryWindow` (right-anchored, same rect as `CombatLog`) opens via `InventoryButton` (left of `LogButton`). `InventorySlot` and `InventoryItemWidget` support drag, drop (with swap), RMB-toggle, and hover-tooltip via `to_info_data()`. Empty backpack cells render as drop targets — total cells = `max(20, items + 4)`.

---

## Tooltip pattern (`to_info_data()`)

`SpellResource`, `StatusEffect`, `BoundItemResource`, `AccessoryResource` implement:

```
func to_info_data(...) -> Dictionary
# returns { title, icon, subtitle, description, lines: [{label, value}, ...] }
```

Subclasses extend via `super.to_info_data()` and override fields. The single `InfoPanel` (registered in `CombatContext.info_panel`) renders any such dict via `show_for(anchor, data)` / `hide_panel()`. New spells/statuses/items get tooltips automatically — just override and return a dict.

Consumers: `SpellButton`, `StatusEffect._on_mouse_entered` (base), `InventorySlot`, `InventoryItemWidget`, `ArenaIcon` (builds dict manually from `arena.def`).

---

## Mechanics

### Heat

- Range `0..Player.max_heat` (200). Soft cap `overflow_threshold = 100` (raised by items).
- End of player turn: if `heat > overflow_threshold`, player takes `(heat - threshold)` raw OVERFLOW damage.
- `Collect Heat` is free but `ends_turn = true`. Multiple casts per turn allowed while Heat permits.

### Burning cycle

`BurningStatus` (UNIQUE). `stacks` is repurposed as `stored_reward` (set on apply; further applications add fuel **only during Smoldering**, otherwise rejected).

```
Smoldering → Kindling → Blazing → Fading → removed
```

Stage transitions in `on_turn_start` (host's turn).

| Stage      | ATTACK from host  | CollectHeat coefficient |
|------------|-------------------|-------------------------|
| Smoldering | normal            | 0.0                     |
| Kindling   | × 0.5             | 0.5                     |
| Blazing    | 0, canceled       | 1.5                     |
| Fading     | × 0.5             | 1.0                     |

---

## Signals (EventBus)

Most-used:

| Signal                          | Payload                              | Direction                          |
|---------------------------------|--------------------------------------|------------------------------------|
| `spell_cast`                    | `SpellResource`                      | SpellPanel → CombatManager         |
| `spell_resolved`                | —                                    | CombatManager → SpellPanel         |
| `spell_cast_resolved` / `spell_canceled` | `SpellCastInfo`             | Combatant.cast → listeners         |
| `target_selected`               | `Enemy`                              | Enemy.ClickArea → CombatManager    |
| `turn_started` / `turn_ended_by`| `actor`                              | CombatManager → StatusContainers   |
| `turn_ended`                    | —                                    | SpellPanel → CombatManager         |
| `heat_changed` / `player_hp_changed` | `int`                           | Player → HUD                       |
| `combat_initialized`            | `max_hp, hp, max_heat, heat`         | Player → HUD                       |
| `damage_dealt`                  | `DamageInfo`                         | Combatant.deal_damage              |
| `status_applied` / `status_removed` | `carrier, status`                | StatusContainer                    |
| `status_stacks_changed`         | `carrier, status, delta`             | StatusContainer                    |
| `spellbook_changed`             | `owner, Array[SpellResource]`        | Spellbook → HUD                    |
| `bound_slot_equipped/unequipped`| `spell_id[, item]`                   | Inventory                          |
| `accessory_slot_equipped/unequipped` | `slot_index[, accessory]`       | Inventory                          |
| `log_entry`                     | `String`                             | anywhere → CombatLog               |
| `spell_selected`                | `SpellResource`                      | CombatManager → Cursor             |
| `enemy_hover_entered/exited`    | `Enemy`                              | Enemy.ClickArea → Cursor           |

Reserved/legacy (declared but unused): `player_status_changed`, `spells_loaded`, `state_changed`, `combat_finished`.

---

## File map

```
features/
  core/
    event_bus.gd, combat_context.gd, combatant.gd
    pipeline/{damage_info, spell_cast_info, status_change_request}.gd

  combat/
    combat_manager.{gd,tscn}
    arena/{arena.{gd,tscn}, arena_resource.gd, arena_battle_start_entry.gd, basic_arena.tres}
    formation/
      enemy_formation.gd, formation_resource.gd, formation_slot.gd
      front_heavy.tres, back_heavy.tres
    room/{room.{gd,tscn}, room_enemy_entry.gd}

  combatants/
    player/{player.gd, player.tscn}
    enemy/
      enemy.gd, enemy_slot.tscn, enemy_resource.gd
      skeleton/{skeleton.tres, skeleton_warrior.png}

  spells/
    spell_resource.gd, spellbook.gd
    effects/{spell_effect_resource, deal_damage_effect, apply_status_effect,
             collect_heat_effect, burning_effect}.gd
    spark/{spark.tres, spark.svg, spark_name.svg}
    collect_heat/{collect_heat.tres, collect_heat.svg, collect_heat_active.svg}
    heat_touch/{heat_touch.tres, heat_touch.svg, heat_touch_active.svg}
    shield/{shield.tres, shield.svg, shield_active.svg}
    armor/{armor.tres, armor.svg, armor_active.svg}

  statuses/
    status_effect.gd, status_container.gd
    burning/{burning_status.gd, burning.tscn,
             smoldering.svg, kindling.svg, blazing.svg, fading.svg}
    shield/{shield_status.gd, shield_status.tscn}
    armor/{armor_status.gd, armor_status.tscn}
    item_mods/
      collect_glove_mod/{collect_glove_mod.gd, collect_glove_mod.tscn}
      spark_glove_mod/{spark_glove_mod.gd, spark_glove_mod.tscn}
      heat_touch_helm_mod/{heat_touch_helm_mod.gd, heat_touch_helm_mod.tscn}
      max_heat_mod/{max_heat_mod.gd, max_heat_mod.tscn}

  inventory/
    inventory.{gd,tscn}, bound_item_resource.gd, accessory_resource.gd
    bound/
      glove_collect/glove_collect.tres
      glove_spark/glove_spark.tres
      helm_heat_touch/helm_heat_touch.tres
    accessories/
      amulet_max_heat/amulet_max_heat.tres
    ui/
      {inventory_button, inventory_window, inventory_slot,
       inventory_item_widget, inventory_backpack_drop}.{gd,tscn}

  ui/
    {hud, spell_panel, spell_button, stat_bar,
     info_panel, arena_icon, combat_log, log_button}/{<name>.gd, <name>.tscn}
    cursor/{cursor.gd, cursor.tscn, cursor.svg, cursor_red.svg}
```

`main.tscn`, `project.godot`, `icon.svg` live at root. Item icons currently link to their bound spell's icon as a placeholder; long-term each item gets its own.

---

## Gotchas

- **`%NodeName` fails silently** if "Unique Name in Owner" isn't enabled on the node.
- **`class_name` is global**; restart editor after renames.
- **`Resource` is not a Node** — no `@onready`, no `_ready`, no `$Child`.
- **`preload(...).instantiate()` + `init()`**: add to tree before `init` if `init` touches `@onready` vars.
- **Statuses are `Control` scenes** with size — they affect `StatusContainer` (HBox) layout.
- **Enemy `ClickArea` must not cover `StatusContainer`** — `Button` with `mouse_filter = STOP` swallows status hovers and breaks tooltips. In `enemy_slot.tscn` the click area is anchored under the column (`offset_top = 81`) and `TextureRect.mouse_filter = IGNORE`. If you change column height, sync the offset.
- **HUD doesn't load spells** — it listens to `spellbook_changed`. New spells go into `Player.basic_spells`, the spellbook, or via Inventory accessory.
- **Move files with their UID sidecars.** `.gd` always travels with its `.gd.uid`; `.svg`/`.png` with their `.import`. Godot's FileSystem dock does this automatically; manual moves must take the pair. A bare move regenerates the UID and breaks every reference.
- **Don't add nodes to an instanced sub-scene from the outer scene** (`[node parent="Instance/Child"]`). Godot drops such overrides on re-save when any reference temporarily fails to resolve. Add them in the same scene where the parent lives, or via a runtime spawn API like `EnemyFormation.populate()`.
- When emitting an EventBus signal, payload type must match the declaration.

---

## Don'ts

- Don't rewrite working code unasked.
- Don't add features beyond the task.
- No `# TODO` / `# add logic here` placeholders.
- Don't branch on `spell.id` in `CombatManager` — write a `SpellEffectResource`.
- Don't put game state (HP, Heat, burn stage) in UI scripts.
- Don't bypass `Combatant.cast` / `Combatant.deal_damage`.
- Don't mutate game state inside `modify_pre_cast` (breaks `preview_spell`).
- Don't suggest C# or a different Godot version.
- Always specify node type when describing scene structure: `HpBar (StatBar)`, not `HpBar`.
