# burn_them_all — архитектура

Пошаговый dungeon-crawler с одним персонажем — пиромантом. Godot 4.6.1, GDScript.
Документ описывает **как устроен проект** и **куда смотреть, когда хочешь что-то добавить**.

Краткая сводка для AI-инструкций — `CLAUDE.md`. Накопленные правила «как делать не надо» — `.claude/lessons.md`.

---

## 1. Идея игры

- **Пиромант** — единственный играбельный класс. Бросает огненные заклинания.
- Враги горят постадийно. Чтобы извлечь из горения максимум выгоды (тепло, урон), нужно уметь распоряжаться его фазами.
- **Heat (Тепло)** — двойной ресурс: одновременно «очки действия» и «опасность». Превышение порога 100 в конце хода ранит самого игрока.
- Порядок хода: игрок может кастовать заклинания пока хватает Heat → нажимает End Turn (или кастует «оканчивающее» заклинание) → ходят враги → новый ход игрока.

---

## 2. Стек и общие правила

- Godot **4.6.1**, скрипты на **GDScript**.
- Отступы — **4 пробела**, без табов.
- `class_name` уникальны на весь проект (Godot хранит их глобально).
- Имена файлов — `snake_case`, имена нод в сцене — `PascalCase`.
- Доступ к узлам внутри сцены — через `%NodeName` (флаг «Unique Name in Owner» в инспекторе ноды должен быть включён).
- В классах `Resource` нельзя использовать `@onready` (Resource — не нода).

---

## 3. Главный архитектурный принцип

Проект организован **vertical slicing**: **одна фича = одна папка**. Базовые классы лежат на уровень выше, конкретные экземпляры — рядом со своими ресурсами и сценами.

Например, всё, что относится к Spark, лежит в `features/spells/spark/`:
```
features/spells/
    spell_resource.gd         ← базовый класс
    spark/
        spark.tres            ← данные
        spark.svg             ← иконка
        spark_name.svg        ← активная иконка
```

Поверх этого — **жёсткое разделение на три слоя**:

| Слой    | Где лежит                        | Что можно                                   | Чего нельзя                              |
| ------- | -------------------------------- | ------------------------------------------- | ---------------------------------------- |
| Данные  | `*Resource.gd` + `.tres`         | Хранить значения, ссылки на сцены/ресурсы   | Содержать игровую логику, лезть в ноды   |
| Логика  | `core/`, `combat/`, `combatants/`, `statuses/`, `inventory/` | Считать урон, хранить Heat/HP, менять состояния | Прямо обращаться к UI, вызывать `$Hud/...` |
| Дисплей | `ui/` (и `inventory/ui/`)        | Подписываться на сигналы, рисовать, отдавать ввод | Хранить «правду» (HP, Heat, стадии горения) |

UI получает данные через сигналы EventBus и **никогда** не является источником истины.

### 3.1. Cross-cutting инфраструктура: `core/`

Часть кода действительно живёт между фичами (pipeline-объекты, autoload'ы, базовый `Combatant`). Эта инфраструктура лежит в `features/core/` и не привязана к конкретной фиче.

### 3.2. Item-modifier статусы

Невидимые статусы, существующие только ради конкретного предмета (`collect_glove_mod`, `spark_glove_mod` и т.п.), вынесены в `features/statuses/item_mods/`. Они формально статусы, но не самостоятельные фичи. Связь с предметом — через `BoundItemResource.modifier_status` (PackedScene-ссылка).

### 3.3. Иконки

Иконки спеллов лежат рядом со спеллом (`features/spells/spark/spark.svg`). Bound-предметы временно ссылаются на иконки своих спеллов как плейсхолдер; в перспективе у каждого предмета будет своя иконка в `features/inventory/bound/<id>/`.

---

## 4. Раскладка проекта

```
features/
  core/                            — pipeline + autoload'ы + базовый Combatant
    event_bus.gd
    combat_context.gd
    combatant.gd
    pipeline/
      damage_info.gd
      spell_cast_info.gd
      status_change_request.gd

  combat/                          — оркестрация боя, поле боя
    combat_manager.gd / .tscn
    combat_arena.tscn              ← корневая сцена боя (контейнер)
    arena/
      arena.gd / arena.tscn
      arena_resource.gd
      arena_battle_start_entry.gd
      (arenas/ зарезервировано для .tres арен)
    formation/
      enemy_formation.gd
      formation_resource.gd
      formation_slot.gd
      front_heavy.tres
      back_heavy.tres

  combatants/
    player/
      player.gd / player.tscn
    enemy/
      enemy.gd
      enemy_slot.tscn
      enemy_resource.gd
      skeleton/
        skeleton.tres
        skeleton_warrior.png

  spells/
    spell_resource.gd              ← базовый класс
    spellbook.gd                   ← список заклинаний бойца
    effects/
      spell_effect_resource.gd     ← базовый эффект
      deal_damage_effect.gd
      apply_status_effect.gd
      collect_heat_effect.gd
      burning_effect.gd            (бывший IgniteEffect)
    spark/        spark.tres + spark.svg + spark_name.svg
    collect_heat/ collect_heat.tres + collect_heat.svg + collect_heat_active.svg
    heat_touch/   heat_touch.tres + heat_touch.svg + heat_touch_active.svg
    shield/       shield.tres + shield.svg + shield_active.svg

  statuses/
    status_effect.gd               ← базовый класс
    status_container.gd            ← контейнер статусов на бойце/арене
    burning/
      burning_status.gd / burning.tscn
      smoldering.svg + kindling.svg + blazing.svg + fading.svg
    shield/
      shield_status.gd / shield_status.tscn
    item_mods/                     ← статусы-модификаторы предметов
      collect_glove_mod/
      spark_glove_mod/
      heat_touch_helm_mod/
      max_heat_mod/

  inventory/
    inventory.gd / inventory.tscn  ← система слотов под Player
    bound_item_resource.gd
    accessory_resource.gd
    bound/
      glove_collect/glove_collect.tres
      glove_spark/glove_spark.tres
      helm_heat_touch/helm_heat_touch.tres
    accessories/
      amulet_max_heat/amulet_max_heat.tres
    ui/
      inventory_button, inventory_window, inventory_slot,
      inventory_item_widget, inventory_backpack_drop

  ui/                              ← общий HUD-каркас
    hud/, spell_panel/, spell_button/, stat_bar/, info_panel/,
    arena_icon/, combat_log/, log_button/
```

`addons/`, `main.tscn`, `project.godot`, `icon.svg` лежат на корне.

Размер по фичам (для масштаба):

```
core         12 files    combat       19 files    combatants   11 files
spells       34 files    statuses     30 files    inventory    25 files
ui           24 files
```

---

## 5. Подсистемы

### 5.1. EventBus (`core/event_bus.gd`)

Глобальная шина сигналов (autoload). Любой код, общающийся с внешним миром, делает это здесь. Локальные сигналы (внутри одной сцены) — на ноде, не в EventBus.

**Часто используемые:**

| Сигнал                          | Payload                              | От кого → кому                     |
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

Reserved/legacy (объявлены, но не используются): `spell_selected`, `player_status_changed`, `spells_loaded`, `state_changed`, `combat_finished`, `turn_ended` (no-arg форма).

### 5.2. CombatContext (`core/combat_context.gd`)

Глобальный реестр участников боя (autoload):

```
CombatContext.player    : Combatant
CombatContext.enemies   : Array[Combatant]
CombatContext.arena     : Node  (Arena)
CombatContext.info_panel: InfoPanel
```

`Player` и `Enemy` сами регистрируются в `_ready` и удаляются на `tree_exiting`. `CombatContext.all_combatants()` возвращает игрока + врагов. `CombatContext.reset()` очищает всё.

### 5.3. Иерархия Combatant

```
Combatant (extends Control)        features/core/combatant.gd
  ├── Player (extends Combatant)   features/combatants/player/player.gd
  └── Enemy  (extends Combatant)   features/combatants/enemy/enemy.gd
```

Любой боец имеет двух обязательных детей:

- `%StatusContainer` — `HBoxContainer`
- `%Spellbook`       — `Node`

Базовые методы (`Combatant`):

- `cast(spell, target) -> bool` — единый путь применения заклинания (см. §5.5)
- `deal_damage(target, amount, type, ability_id) -> DamageInfo` — единый путь нанесения урона (см. §5.6)
- `apply_raw_damage(amount)` — снять HP «насухо», в обход всех модификаторов (использовать только из `deal_damage` или для системного урона типа overflow)
- `preview_spell(spell) -> SpellCastInfo` — прогнать pre_cast без оплаты и без execute, для UI

`Player` поверх этого добавляет `heat`, `max_heat`, `overflow_threshold`, `Inventory` и эмитит `player_hp_changed` / `heat_changed` / `combat_initialized`.
`Enemy` добавляет `EnemyResource`, кликабельную область, `take_turn(target)` и регистрацию в `CombatContext.enemies`.

> **Правило:** не обходи `cast` и `deal_damage`. На них висят все статусы и арена.

### 5.4. Статусы (`StatusEffect` + `StatusContainer`)

Статус — сцена `.tscn`, чей корень — `StatusEffect extends Control`. Это позволяет статусу нести иконку, лейбл стаков и т.п. прямо в ноде.

Каждый `Combatant` (и `Arena`) имеет `StatusContainer`, который:

- хранит статусы как своих детей,
- ловит `turn_started` / `turn_ended_by` для своего носителя и зовёт `on_turn_start` / `on_turn_end` у каждого статуса,
- прогоняет урон/касты/изменения статусов через все статусы по убыванию `priority`.

**Жизненный цикл статуса (override что нужно):**

```
on_apply()                          — когда статус впервые накладывается
on_remove()                         — перед удалением
on_stacks_changed(delta)            — при изменении стаков
on_turn_start() / on_turn_end()     — на ходах носителя

modify_outgoing_damage(info)        — изменить/отменить исходящий урон от носителя
modify_incoming_damage(info)        — изменить/отменить входящий урон по носителю
on_damage_dealt(info)               — реакция после успешного удара
on_damage_taken(info)               — реакция после получения урона

modify_pre_cast(info)               — перехват каста носителя (можно отменить)
modify_pre_cast_incoming(info)      — перехват каста по носителю
modify_post_cast(info)              — пост-обработка после применения эффектов

intercept_status_change(req)        — перехват apply/remove/stacks (можно отменить)
```

**Поля `StatusEffect`:**

- `id : StringName` — обязательный, по нему ищется статус (`statuses.find(&"burning")`)
- `display_name : String`
- `stack_mode : { DURATION, INTENSITY, REFRESH, UNIQUE }` — DURATION/INTENSITY суммируют, REFRESH берёт максимум, UNIQUE игнорирует повторы
- `priority : int` — больше = раньше в обработке
- `stacks : int` — текущее значение
- `host : Node` — кто его носит

**Существующие статусы:**

- `BurningStatus` — горение в 4 стадиях (см. §6.2)
- `ShieldStatus`  — поглощает следующий удар, тратит стак
- `CollectGloveMod`, `SparkGloveMod`, `HeatTouchHelmMod`, `MaxHeatMod` — невидимые item-mod статусы (`features/statuses/item_mods/`). Все UNIQUE, `priority = 0`. Шаблон: фильтруют по `info.spell.id` и не трогают чужие касты.

### 5.5. Заклинания и эффекты (data-driven)

`SpellResource` (`features/spells/spell_resource.gd`) — это **данные**:

- `id`, `spell_name`, `description`, `icon`, `icon_active`
- `heat_cost`, `heat_reward`, `ends_turn`
- `target_type : { SINGLE_ENEMY, SINGLE_BURNABLE, ALL_BURNING, SELF, NONE }`
- `effects : Array` — массив `SpellEffectResource`

Каждый эффект — отдельный класс, унаследованный от `SpellEffectResource` и реализующий:

```gdscript
func execute(info: SpellCastInfo) -> void
```

**Существующие эффекты** (`features/spells/effects/`):

| Класс              | Что делает                                                                      |
| ------------------ | ------------------------------------------------------------------------------- |
| `DealDamageEffect` | `caster.deal_damage(target, amount, damage_type, spell.id)`                     |
| `ApplyStatusEffect`| Накладывает `status_scene` на цель (или на кастера, если `apply_to_self=true`) |
| `BurningEffect`    | Накладывает `burning.tscn` на цель с `reward` стаков                            |
| `CollectHeatEffect`| Снимает `BurningStatus` и возвращает кастеру тепло по коэффициенту стадии        |

**Поток каста:**

```
SpellButton → SpellPanel → EventBus.spell_cast(SpellResource)
    → CombatManager._on_spell_cast
        SELF      → player.cast(spell, null) сразу
        иначе     → запоминает selected_spell, ждёт target_selected

Enemy.ClickArea → EventBus.target_selected(enemy)
    → CombatManager._on_target_selected → player.cast(spell, enemy)
```

**Что делает `Combatant.cast(spell, target)`:**

1. Создаёт `SpellCastInfo` с копией `spell.effects`.
2. Прогоняет через `process_pre_cast` (статусы кастера, потом арены, потом цели). Любой статус может выставить `info.canceled = true`.
3. Если отменено — `EventBus.spell_canceled.emit(info)` и выход.
4. `_try_pay_cost(info)` — для `Player` это списывает Heat; для `Enemy` всегда `true`.
5. Каждый эффект вызывает `effect.execute(info)`.
6. `process_post_cast` — статусам нужно знать, что каст случился.
7. `EventBus.spell_cast_resolved.emit(info)`.

> **Правило:** если хочешь добавить новое поведение заклинания — пиши **новый `SpellEffectResource`**. Не добавляй ветки `if spell.id == ...` в `CombatManager`.

**Превью каста (для UI).** `Combatant.preview_spell(spell)` создаёт пустой `SpellCastInfo` с копией `spell.effects`, прогоняет `statuses.process_pre_cast` кастера и арены — **без** оплаты Heat и без `effect.execute`. Возвращает информационный объект:

- `info.extra_data["heat_cost_delta"]` — суммарная дельта стоимости от модификаторов
- `info.effects` — финальный список эффектов (с возможными добавками)

Поверх этого:

- `SpellResource.effective_heat_cost(caster)` → `max(0, heat_cost + delta)`. `SpellButton.init` показывает на иконке именно его.
- `SpellResource.to_info_data(caster)` — в строке `Heat cost` пишет `"20 (-10)"`, в `Damage` — `"0 (+10)"` (база + дельта в скобках; если дельта = 0 — просто число).

> **Важно:** `preview_spell` чистый. Если пишешь модификатор статуса, который трогает что-то кроме `info.extra_data` / `info.effects` в `modify_pre_cast` — это сломает превью.

### 5.6. Урон (`DamageInfo`)

`DamageInfo` (`features/core/pipeline/damage_info.gd`) — RefCounted-объект, текущий через статусы:

```
amount       : int            — модифицируемое значение
type         : Type           — ATTACK | SPELL | BURNING | OVERFLOW | PURE
source       : Combatant      — кто бьёт
target       : Combatant      — кого бьёт
ability_id   : StringName     — id заклинания/способности (или &"")
canceled     : bool           — true = удар не наносится
```

`Combatant.deal_damage(...)`:

1. Создаёт `DamageInfo`.
2. Прогоняет `process_outgoing_damage` (статусы кастера → арена → статусы цели → арена ещё раз для входящего).
3. Если `canceled` — выходит.
4. `target.apply_raw_damage(info.amount)` — наконец списывает HP.
5. `EventBus.damage_dealt.emit(info)`.
6. Зовёт `on_damage_dealt` на статусах кастера и `on_damage_taken` на статусах цели.

Пример: `BurningStatus.modify_outgoing_damage` режет урон ATTACK в стадии Kindling/Fading вдвое, в Blazing — в ноль.

### 5.7. Арена (`Arena` + `ArenaResource`)

`Arena` (`features/combat/arena/arena.gd`) — нода рядом с `CombatManager`, отвечает за «контекст поля боя»:

- держит свой `%StatusContainer` (статусы арены не привязаны к бойцу),
- при `enter_battle()` применяет к бойцам стартовые эффекты из `ArenaResource.battle_start_effects` и накладывает на саму арену `permanent_statuses`,
- участвует **во всех** пайплайнах урона и каста — `Combatant.cast` и `Combatant.deal_damage` явно зовут `CombatContext.arena.statuses.process_*`.

`ArenaResource` (`features/combat/arena/arena_resource.gd`):

- `battle_start_effects : Array[ArenaBattleStartEntry]`
- `permanent_statuses   : Array[PackedScene]`

`ArenaBattleStartEntry` хранит `target_filter : { PLAYER, ENEMIES, ALL }` + `status_scene` + `stacks`.

### 5.8. Spellbook (`features/spells/spellbook.gd`)

Нода-список заклинаний у каждого бойца. Любое изменение спеллбука эмитит `spellbook_changed(owner, spells)`. HUD слушает только спеллбук игрока и обновляет панель.

### 5.9. Inventory (только у игрока)

`Inventory` (`features/inventory/inventory.gd`) живёт под Player и управляет тремя видами хранилищ:

- **Bound slots** — `BoundItemResource` модифицирует конкретное заклинание тем, что вешает на игрока `modifier_status`. Связь: `BoundItemResource.bound_spell_id == spell.id`. Слот идентифицируется этим же id (`&"collect_heat"`, `&"spark"`, `&"heat_touch"`).
- **Accessory slots** — `AccessoryResource` может добавить заклинание (`granted_spell`) и/или повесить пассивные статусы (`passive_statuses`). Слотов фиксировано 4, идентифицируются индексом.
- **Backpack** — безразмерный `Array` неактивных предметов. Идентификатор — индекс.

Inventory сам отслеживает наложенные через него статусы (`_bound_status_refs` / `_accessory_status_refs`) и снимает их при unequip.

**Единый API перемещения:**

```
Inventory.transfer(from_kind, from_key, to_kind, to_key) -> bool
Inventory.toggle_equip(kind, key) -> bool
```

`transfer` обрабатывает три случая в одном месте:
- Свободный слот назначения → переносит.
- Занятый совместимый слот и не-backpack источник → **swap**.
- Занятый совместимый слот и backpack-источник → старый предмет уезжает в backpack.

Совместимость в `Inventory.is_compatible(kind, key, item)`:
- BOUND принимает только `BoundItemResource` с `bound_spell_id == key`.
- ACCESSORY принимает только `AccessoryResource`.
- BACKPACK принимает что угодно.

`toggle_equip` — короткий путь для ПКМ: из backpack → в первый подходящий пустой/совпадающий слот; из слота → в backpack.

**Сигналы:** `Inventory.changed` (локальный) + `EventBus.bound_slot_equipped/unequipped`, `EventBus.accessory_slot_equipped/unequipped` (глобальные). UI слушает локальный `changed` и перерисовывает окно полностью.

**Связь с UI заклинаний.** `Player._ready` подписывается на `Inventory.changed` и переэмитит `EventBus.spellbook_changed` с тем же списком спеллов. Это нужно, чтобы `SpellPanel` пересоздал кнопки и пересчитал effective-стоимости через `preview_spell`.

#### 5.9.1. UI инвентаря

```
InventoryButton → InventoryWindow.open()
InventoryWindow:
    "Equipment"   — 3 InventorySlot (Left/Right/Head, kind=BOUND, bound_spell_id из кода)
    "Accessories" — 4 InventorySlot (kind=ACCESSORY, slot_index=0..3)
    "Backpack"    — ScrollContainer(InventoryBackpackDrop) → GridContainer → InventoryItemWidget × N
```

- `InventoryButton` — зеркало `LogButton`, открывает `InventoryWindow`, прячется на время открытия.
- `InventoryWindow` — анкорится в правый верхний угол (тот же rect, что `CombatLog`).
- `InventorySlot` — экспортит `kind`, `bound_spell_id`/`slot_index`, `label_text`. ЛКМ-drag, drop через `_can_drop_data`/`_drop_data` → `Inventory.transfer`. ПКМ → `Inventory.toggle_equip`. Hover → `info_panel.show_for(self, item.to_info_data())` если в слоте есть предмет.
- `InventoryItemWidget` — ячейка backpack: заполненная (drag/ПКМ/tooltip активны) или пустая (drop-цель, placeholder `—`).
- `InventoryBackpackDrop` — fallback drop-зона на пустое место сетки.

`InventoryWindow._rebuild_backpack` всегда рендерит `max(20, backpack.size() + 4)` ячеек.

### 5.10. InfoPanel — универсальный hover-popup

`InfoPanel` (`features/ui/info_panel/info_panel.gd`) — переиспользуемое окно с информацией: арена, статусы, заклинания, предметы.

**Контракт:**

```
info_panel.show_for(anchor: Control, data: Dictionary)
info_panel.hide_panel()
```

**Ключи `data`** (все опциональны, кроме `title`):

- `title : String`
- `icon : Texture2D`
- `subtitle : String` ("Status", "Spell", "Battlefield")
- `description : String` — основной текст с автопереносом
- `lines : Array[Dictionary]` — массив `{label, value}`-строк

**Позиционирование:** справа от anchor с зазором 8 px, верх по верху anchor → если не лезет, отзеркаливается влево → если не лезет вниз, подтягивается вверх → финальный clamp в viewport. На время репозиционирования popup невидим (один кадр).

**Регистрация:** один экземпляр инстансится в `main.tscn`, на `_ready()` публикует себя в `CombatContext.info_panel`. Все консьюмеры (`ArenaIcon`, `SpellButton`, `StatusEffect`, инвентарь) обращаются через `CombatContext.info_panel`.

### 5.11. `to_info_data()` — паттерн «toString»

`SpellResource`, `StatusEffect`, `BoundItemResource`, `AccessoryResource` определяют:

```
func to_info_data(...) -> Dictionary
```

Подкласс расширяет через `super.to_info_data()`.

**Базовые реализации:**

- `SpellResource.to_info_data(caster: Combatant = null)` — `{title, icon, subtitle: "Spell", description, lines}`. С caster — прогоняет `preview_spell(self)` и форматирует `Heat cost` / `Damage` как `"<base> (<delta>)"`.
- `StatusEffect.to_info_data()` — `{title, subtitle: "Status", lines: [Stacks]}`.
- `BoundItemResource.to_info_data()` — `{title, icon, subtitle: "Bound Item", description}`.
- `AccessoryResource.to_info_data()` — `{title, icon, subtitle: "Accessory", description}`.

**Override'ы:** `BurningStatus` подставляет иконку по стадии и пишет stage/stored/coefficient. `ShieldStatus` подставляет свою текстуру.

**Кто рисует:**

- `SpellButton.init()` подключает `click_area.mouse_entered/exited` и зовёт `info_panel.show_for(self, spell.to_info_data(CombatContext.player))`.
- `StatusEffect._ready()` (база) — выставляет всем дочерним `Control` `mouse_filter = IGNORE` и сам зовёт `to_info_data()`.
- `InventorySlot` / `InventoryItemWidget` — на hover тащат предмет через `inventory.peek(...)` и зовут `info_panel.show_for(self, item.to_info_data())` (через `has_method`-проверку — для будущих типов tooltip автоматически).

> **Правило:** новые спеллы/статусы/предметы получают tooltip автоматически. Хочешь дополнительные строки или другое описание — переопредели `to_info_data()` и зови `super.to_info_data()` для базы.

### 5.12. ArenaIcon, CombatLog, LogButton

**`ArenaIcon`** (`features/ui/arena_icon/`) — кнопка 48×48 в левом верхнем углу. На hover строит `Dictionary` из `CombatContext.arena.def` и зовёт `info_panel.show_for(self, data)`. Если `arena.def == null` — заглушка «Plain arena. No special effects.»

**`CombatLog`** (`features/ui/combat_log/`) — окно лога боя. API: `open()`, `close()` + сигнал `closed`. Подписан на `EventBus.log_entry` и копит записи независимо от видимости.

**`LogButton`** (`features/ui/log_button/`) — кнопка 48×48 в правом верхнем углу. По клику открывает `CombatLog` и прячется; возвращается по сигналу `closed`. По геометрии совпадает с `×` внутри лога — кнопка «не двигается» при открытии.

### 5.13. EnemyFormation — расстановка и спавн врагов

Формации **заданы как данные**, расстановка управляется кодом.

**Данные:**

- `FormationSlot` — `{position: Vector2, row: int}`. `row` для логики (AoE по ряду, line-of-sight) и z-порядка.
- `FormationResource` — `{id, display_name, slots: Array[FormationSlot]}`.

**Логика** (`features/combat/formation/enemy_formation.gd`, `Control + script`):

```gdscript
@export var formation: FormationResource

func populate(new_formation: FormationResource, entries: Array) -> void
func _layout() -> void
```

`populate(formation, entries)` — единый рантайм-API:

1. Заменяет `formation`.
2. Чистит существующих Enemy-детей (`queue_free`).
3. Под каждый `entry` (`{slot_index: int, enemy_data: EnemyResource}`) инстансит `enemy_slot.tscn`, выставляет поля, добавляет в дерево.
4. Зовёт `_layout()`.

`_layout()`: для каждого Enemy-ребёнка ставит `position = formation.slots[enemy.slot_index].position`, потом `_restack` сортирует детей по убыванию `slot.row` (задние ряды раньше в дереве → рисуются под передними).

**Готовые формации (`features/combat/formation/`):**

| Файл | Слоты 0–2 (`row=0` или `row=1`) | Слоты 3–4 |
|---|---|---|
| `front_heavy.tres` | передний ряд (3 слота, x=0/154/308, y=100) | задний (2 слота, x=77/231, y=0) |
| `back_heavy.tres`  | задний ряд (3 слота, x=0/154/308, y=0)   | передний (2 слота, x=77/231, y=100) |

Конвенция: индексы 0–2 — основной ряд (3 слота), 3–4 — вторичный (2 слота, между ними по горизонтали).

**Размеры:** контейнер 458×300, исходит из `enemy_slot.tscn` 150×200 + спейсинг 4 px между слотами и 100 px между рядами по Y.

**Где зовётся `populate()`.** Сейчас — в `CombatManager._spawn_initial_encounter()` (`combat_manager.gd:25`), временный хардкод (`back_heavy` + два `skeleton.tres` в слотах 3 и 4). Будущий генератор комнат заменит этот метод.

`combat_arena.tscn` — пустой контейнер с `EnemyFormation` без `formation`-оверрайда и без Enemy-детей: всё население сцены приходит через `populate`.

> **Правило:** не добавляй врагов в сцену через node-overrides из `main.tscn` (`[node ... parent="CombatArena/EnemyFormation"]`). Godot выкидывает такие overrides при ре-сейве, если хоть одна ссылка временно невалидна. Враги добавляются либо прямо в той сцене, где `EnemyFormation` живёт, либо через рантайм-`populate`.

---

## 6. Главные механики

### 6.1. Heat

- Хранится в `Player.heat`, потолок `Player.max_heat` (200 по умолчанию).
- «Опасный порог» — `Player.overflow_threshold` (100 по умолчанию). Если в конце хода `heat > threshold`, игрок получает `(heat - threshold)` урона типа OVERFLOW.
- `Collect Heat` — единственный «бесплатный» спелл, заканчивает ход (`ends_turn = true`).
- Стоимости списываются в `Player._try_pay_cost` (внутри `cast`), награда возвращается через `gain_heat`.

### 6.2. Цикл горения

```
Smoldering → Kindling → Blazing → Fading → удаление
```

Стадии переключаются в `BurningStatus.on_turn_start` (на ходе **носителя статуса**).

**Эффект на исходящий ATTACK от горящего:**

| Стадия     | Множитель урона      |
| ---------- | -------------------- |
| Smoldering | 1.0                  |
| Kindling   | 0.5                  |
| Blazing    | 0 + удар отменяется  |
| Fading     | 0.5                  |

**Сбор тепла через `CollectHeatEffect` = `stored_reward * coefficient`:**

| Стадия     | Коэффициент |
| ---------- | ----------- |
| Smoldering | 0.0         |
| Kindling   | 0.5         |
| Blazing    | 1.5         |
| Fading     | 1.0         |

`BurningStatus` UNIQUE: `stacks` зафиксирован = 1 после `on_apply`, реальное «топливо» хранится в `stored_reward`. Повторное применение дописывает топливо **только в стадии Smoldering**, в остальных — отбрасывается.

---

## 7. Поток хода

```
[Начало боя]
    CombatManager._start_combat
    ├── _spawn_initial_encounter (хардкод; будущий генератор)
    │       formation_node.populate(BACK_HEAVY, [{slot=3, skeleton}, {slot=4, skeleton}])
    ├── arena.enter_battle()              — навешиваются стартовые статусы арены
    └── EventBus.turn_started(player)

[Игрок жмёт спелл]
    SpellButton → SpellPanel → EventBus.spell_cast(SpellResource)
    CombatManager._on_spell_cast
        SELF      → player.cast(spell, null)
        иначе     → запоминает selected_spell

[Игрок жмёт врага]
    Enemy.ClickArea.pressed → EventBus.target_selected(enemy)
    CombatManager._on_target_selected → player.cast(spell, enemy)

[Внутри Combatant.cast]
    pre_cast (статусы кастера → арены → цели)
    pay cost
    for effect in spell.effects: effect.execute(info)
        DealDamageEffect → caster.deal_damage(...)
            modify_outgoing → modify_incoming → apply_raw_damage → on_damage_*
    post_cast
    EventBus.spell_cast_resolved

[Если spell.ends_turn или нажат End Turn]
    EventBus.turn_ended → CombatManager._end_player_turn
        EventBus.turn_ended_by(player)        — статусы игрока обрабатывают on_turn_end
        Heat overflow → player.apply_raw_damage
        for enemy in enemies:
            EventBus.turn_started(enemy)      — статусы врага обрабатывают on_turn_start
            enemy.take_turn(player)
            EventBus.turn_ended_by(enemy)
        EventBus.turn_started(player)
```

---

## 8. Как добавить...

### ...новое заклинание

1. `features/spells/<id>/` — папка со всем нужным:
   - `<id>.tres` со скриптом `SpellResource`,
   - иконки `<id>.svg`, `<id>_active.svg` (если нужны).
2. Заполни `id`, `spell_name`, `heat_cost`, `target_type`, иконки.
3. В поле `effects` собери массив суб-ресурсов нужных эффектов.
4. Если поведение нестандартное — собери из существующих эффектов или напиши новый (см. ниже).
5. Чтобы спелл оказался у игрока — добавь в `Player.basic_spells` в `features/combatants/player/player.tscn`. Чтобы у врага — в `EnemyResource.spells`.

### ...новый эффект заклинания

1. `features/spells/effects/<имя>_effect.gd`:

   ```gdscript
   extends SpellEffectResource
   class_name MyNewEffect

   @export var some_param: int

   func execute(info: SpellCastInfo) -> void:
       # info.caster, info.target, info.spell, info.effects, info.extra_data
       ...
   ```

2. Эффект — `Resource`, не `Node`: никаких `@onready`, `_ready`. Только данные + `execute`.
3. Подключай эффект в любой `.tres` через `SubResource`.

### ...новый статус

1. `features/statuses/<имя>/<имя>.gd`:

   ```gdscript
   extends StatusEffect
   class_name MyStatus

   func _init() -> void:
       id = &"my_status"
       display_name = "My Status"
       stack_mode = StackMode.INTENSITY
       priority = 5
   ```

2. Переопредели нужные хуки.
3. Сцена `features/statuses/<имя>/<имя>.tscn`: корень со скриптом + дочерние ноды для иконки/лейбла.
4. Включи «Unique Name in Owner» для всех `%`-нод.
5. Накладывай через `combatant.statuses.apply(preload("res://features/statuses/<имя>/<имя>.tscn"), 1)` или из `ApplyStatusEffect`.

### ...нового врага

1. `features/combatants/enemy/<id>/<id>.tres` — `EnemyResource` (имя, HP, base_damage, заклинания, начальные статусы).
2. Туда же — иконки/спрайты.
3. По умолчанию враг — инстанс `enemy_slot.tscn` с подменённым `enemy_data` (в т.ч. через `populate()`).
4. Для уникального поведения — наследник `Enemy` с переопределённым `take_turn(target)` либо новый AI-статус.

### ...новую формацию

1. `features/combat/formation/<id>.tres` — `FormationResource` с массивом `FormationSlot`.
2. Конвенция: чем больше `row`, тем дальше от камеры. Передний ряд — `row = 0`.
3. Никакого кода трогать не нужно — `EnemyFormation.populate` подхватит формацию и расставит врагов по `slot_index`.

### ...новый энкаунтер (бой)

1. **Сейчас (один бой):** правишь хардкод в `CombatManager._spawn_initial_encounter` — меняешь формацию и/или массив `entries`.
2. **Когда дойдёт до генератора:**
   - Класс-генератор зовёт `formation_node.populate(formation, entries)` сам — `_spawn_initial_encounter` уходит.
   - `entries` — `Array[Dictionary]` с `{slot_index: int, enemy_data: EnemyResource}`.
3. **Когда дойдёт до multiple-encounter сцен:** делай отдельные сцены через **Scene inheritance** от `combat_arena.tscn` (FileSystem dock → ПКМ → "New Inherited Scene"). В наследнике добавляй EnemySlot'ы как детей `EnemyFormation` ВНУТРИ той же сцены — Godot их не выкинет. Не используй node-overrides из `main.tscn` (`[node parent="CombatArena/EnemyFormation"]`) — они хрупкие.

### ...новую арену

1. `features/combat/arena/arenas/<id>.tres` — `ArenaResource`.
2. Заполни `battle_start_effects` (`ArenaBattleStartEntry`-записи: target_filter / status_scene / stacks) и `permanent_statuses` (висят на самой арене).
3. В сцене боя присвой полю `def` нужный ресурс.

### ...новый bound-предмет / аксессуар

**Bound-предмет (модифицирует конкретное заклинание):**

1. Mod-статус: `features/statuses/item_mods/<имя>_mod/<имя>_mod.gd` (наследник `StatusEffect`, `stack_mode = UNIQUE`, `priority = 0`). Фильтруй по `info.spell.id`. Хуки: `modify_pre_cast` (правит cost через `info.extra_data["heat_cost_delta"]`, добавляет эффекты в `info.effects`), `modify_post_cast`, `on_apply` / `on_remove` (для пассивных характеристик типа `overflow_threshold`).
2. Сцена `<имя>_mod.tscn` — `Control` со скриптом, `visible = false` (модификатор невидим — иконку показывает слот инвентаря).
3. `features/inventory/bound/<id>/<id>.tres` (`BoundItemResource`): `id`, `display_name`, `description`, `icon`, `bound_spell_id`, `modifier_status` (PackedScene из шага 2).
4. Чтобы предмет был у игрока со старта — добавь в `Player.inventory.initial_bound`.

**Accessory:**

1. `features/inventory/accessories/<id>/<id>.tres` (`AccessoryResource`): `id`, `display_name`, `description`, `icon`, опционально `granted_spell` (`SpellResource`) и/или `passive_statuses` (`Array[PackedScene]`).
2. Если нужен пассивный эффект — обычный статус (необязательно невидимый), накладывается через `passive_statuses`.
3. Со старта — `Player.inventory.initial_accessories` (макс 4).

**Помни:**

- `description` обязательно — попадает в hover-tooltip предмета через `to_info_data()`.
- `preview_spell` запускает `modify_pre_cast` без оплаты Heat. Не делай в этом хуке ничего, что меняет состояние игры (логирование, изменение HP/Heat, наложение статусов) — только мутации `info`.
- При экипировке/снятии `Inventory.changed` → `Player` переэмитит `spellbook_changed` → `SpellPanel` пересоздаст кнопки. Tooltip и effective-стоимости пересчитаются.

### ...новый сигнал

- Внутри одной сцены — объяви на ноде, не трогай EventBus.
- Между подсистемами — добавь в `features/core/event_bus.gd`. Тип параметра в `emit` обязан совпадать с объявлением.

### ...hover-tooltip

Спеллы/статусы/предметы — автоматически через `to_info_data()` (см. §5.11). Для произвольного UI-элемента: подпишись на `mouse_entered` / `mouse_exited`, на вход собери `Dictionary` из `title / icon / subtitle / description / lines` и зови `CombatContext.info_panel.show_for(self, data)`, на выход — `hide_panel()`. Не позиционируй сам — `InfoPanel` сам найдёт место рядом с anchor.

---

## 9. Нюансы и ловушки

- **`%NodeName` ломается молча**, если у ноды не включена «Unique Name in Owner». Проверь сцену перед тем, как ругаться на код.
- **`class_name` глобальный.** Переименовал класс — Godot может ещё держать старое имя в кеше; перезапусти редактор.
- **`Resource` — не нода.** Никаких `@onready`, `_ready`, `$Child`. Если нужна ссылка на сцену — `@export var scene: PackedScene` и `scene.instantiate()` в нужный момент.
- **`preload(...).instantiate()` + `init()`**: если `init` лезет в `@onready`-переменные, сначала добавь экземпляр в дерево (`add_child`), потом зови `init`.
- **Статусы — `Control`-сцены.** Они отображаются в `StatusContainer` (HBox), поэтому имеют размеры и могут влиять на layout.
- **Перенос ассетов с UID-сайдкарами.** `.gd` идёт всегда вместе с `.gd.uid`; `.svg`/`.png` — вместе с `.import`. Перемещение через FileSystem dock в Godot переносит сайдкары автоматически. Через файловую систему — двигай парами вручную, иначе UID пересоздастся и ссылки сломаются.
- **Node-overrides из родительской сцены — хрупкие.** Если в `main.tscn` лежит `[node name="X" parent="Instance/Child"]` для инстансированной сцены, Godot выкидывает его при ре-сейве, если хоть одна ссылка временно не резолвится. Враги/слоты добавляются в той же сцене, где живёт `EnemyFormation`, либо через `populate()`.
- **HUD не загружает спеллы.** Он только слушает `spellbook_changed`. Чтобы спелл появился у игрока — добавь его в `Player.basic_spells` (или через Inventory/Spellbook в рантайме).
- **`ClickArea` врага не должен накрывать `StatusContainer`.** В `enemy_slot.tscn` `ClickArea` (Button с `mouse_filter = STOP`) перехватывает hover-события в своём rect. Если он накроет область статусов — `StatusEffect.mouse_entered` никогда не сработает. Текущая раскладка: `ClickArea` анкорится только под `Column` (`offset_top = 81`), `TextureRect.mouse_filter = IGNORE`. Если меняешь высоту `Column` — синхронизируй `offset_top`.

---

## 10. Что **не** трогать без запроса

- Не переписывать рабочий код, если задача этого не требует.
- Не добавлять фичи сверх постановки.
- Не оставлять `# TODO` и `# add logic here` — либо делаешь, либо нет.
- Не ветвиться по `spell.id` в `CombatManager` (вместо этого — новый `SpellEffectResource`).
- Не хранить игровое состояние (HP, Heat, стадии) в UI-скриптах.
- Не обходить `Combatant.cast` / `Combatant.deal_damage` — на них висят все статусы и арена.
- Не предлагать переход на C# или смену версии Godot.
