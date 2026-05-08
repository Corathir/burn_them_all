# burn_them_all — архитектура

Пошаговый dungeon-crawler с одним персонажем - пиромантом. Godot 4.6.1, GDScript.
Документ описывает **как устроен проект** и **куда смотреть, когда хочешь что-то добавить**.

---

## 1. Идея игры

- **Пиромант** — единственный играбельный класс. Бросает огненные заклинания.
- Враги горят постадийно. Чтобы получить от горения максимум выгоды (тепло, урон), нужно уметь распоряжаться его фазами.
- **Heat (Тепло)** — двойной ресурс: одновременно «очки действия» и «опасность». Превышение порога 100 в конце хода ранит самого игрока.
- Порядок хода: игрок может кастовать заклинания пока хватает Heat → нажимает End Turn (или кастует «оканчивающее» заклинание) → ходят враги → новый ход игрока.

---

## 2. Стек и общие правила

- Godot **4.6.1**, скрипты на **GDScript**.
- Отступы — **4 пробела**, без табов.
- `class_name` уникальны на весь проект (Godot хранит их глобально).
- Имена файлов — `snake_case`, имена нод в сцене — `PascalCase`.
- Доступ к узлам внутри сцены — через `%NodeName` (флаг «Unique Name in Owner» в инспекторе ноды должен быть включён).
- Все custom-ресурсы лежат в `scripts/resources/`, конкретные `.tres` — в `data/`.
- В классах `Resource` нельзя использовать `@onready` (Resource — не нода).

> Перед тем как писать новый код, читай `.claude/lessons.md` — туда копятся накопленные правила «как делать не надо».

---

## 3. Главный архитектурный принцип

**Жёсткое разделение на три слоя:**

| Слой    | Где лежит                             | Что можно                                   | Чего нельзя                                |
| ------- | ------------------------------------- | ------------------------------------------- | ------------------------------------------ |
| Данные  | `scripts/resources/`, `data/*.tres`   | Хранить значения, ссылки на сцены/ресурсы   | Содержать игровую логику, лезть в ноды     |
| Логика  | `scripts/combat/`, `entities/`, `statuses/` | Считать урон, хранить Heat/HP, менять состояния | Прямо обращаться к UI, вызывать `$Hud/...` |
| Дисплей | `scripts/ui/`                         | Подписываться на сигналы, рисовать, отдавать ввод | Хранить «правду» (HP, Heat, стадии горения) |

UI получает данные через сигналы EventBus и **никогда** не является источником истины.

---

## 4. Ключевые подсистемы

### 4.1. EventBus (`autoloads/event_bus.gd`)

Глобальная шина сигналов. Любой код, который должен общаться с внешним миром, делает это здесь.
Локальные сигналы (внутри одной сцены) — объявляй на ноде, не тащи в EventBus.

Полная таблица сигналов — см. `CLAUDE.md` → раздел **Signal reference**.

### 4.2. CombatContext (`autoloads/combat_context.gd`)

Глобальный реестр участников боя:

```
CombatContext.player    : Combatant
CombatContext.enemies   : Array[Combatant]
CombatContext.arena     : Node  (Arena)
```

`Player` и `Enemy` сами регистрируются в `_ready` и удаляются на `tree_exiting`. Когда тебе нужен «игрок» или «список врагов» — бери отсюда, не ищи по путям сцен.

`CombatContext.all_combatants()` возвращает игрока + врагов.
`CombatContext.reset()` очищает всё (для смены сцены боя).

### 4.3. Иерархия Combatant

```
Combatant (extends Control)        scripts/entities/combatant.gd
  ├── Player (extends Combatant)   scripts/entities/player.gd
  └── Enemy  (extends Combatant)   scripts/entities/enemy.gd
```

Любой боец имеет двух обязательных детей:

- `%StatusContainer` — контейнер статусов (`HBoxContainer`)
- `%Spellbook`       — список доступных заклинаний (`Node`)

Базовые методы (определены в `Combatant`):

- `cast(spell, target) -> bool` — единый путь применения заклинания (см. §4.5)
- `deal_damage(target, amount, type, ability_id) -> DamageInfo` — единый путь нанесения урона (см. §4.6)
- `apply_raw_damage(amount)` — снять HP «насухо», в обход всех модификаторов (использовать только из `deal_damage` или для системного урона типа overflow)

`Player` поверх этого добавляет `heat`, `max_heat`, `Inventory` и эмитит `player_hp_changed` / `heat_changed` / `combat_initialized`.
`Enemy` добавляет `EnemyResource`, кликабельную область, `take_turn(target)` и регистрацию в `CombatContext.enemies`.

> **Правило:** не обходи `cast` и `deal_damage`. На них висят все статусы и арена.

### 4.4. Статусы (`StatusEffect` + `StatusContainer`)

Статус — это сцена `.tscn`, чей корень — `StatusEffect extends Control`. Это позволяет статусу нести иконку, лейбл стаков и т.п. прямо в ноде.

Каждый `Combatant` (и `Arena`) имеет `StatusContainer`, который:

- хранит статусы как своих детей,
- ловит `turn_started` / `turn_ended_by` для своего носителя и зовёт `on_turn_start` / `on_turn_end` у каждого статуса,
- прогоняет урон/касты/изменения статусов через все статусы по убыванию `priority`.

**Жизненный цикл статуса (можно переопределять что нужно):**

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
- `stack_mode : { DURATION, INTENSITY, REFRESH, UNIQUE }`
    - DURATION/INTENSITY — `stacks` суммируются
    - REFRESH — `stacks` берёт максимум
    - UNIQUE — повторное применение игнорируется (или обрабатывается вручную в `on_stacks_changed`, как в `BurningStatus`)
- `priority : int` — больше = раньше в обработке
- `stacks : int` — текущее значение
- `host : Node` — кто его носит (Combatant или Arena)

Сейчас в проекте есть статусы:

- `BurningStatus` (`scripts/statuses/burning.gd`) — горение в 4 стадиях
- `ShieldStatus`  (`scripts/statuses/shield.gd`) — поглощает следующий удар, тратит стак

**Статусы-модификаторы предметов** (`scripts/statuses/*_mod.gd`) — невидимые статусы, которые навешивает `Inventory` при экипировке предмета. Все UNIQUE, `priority = 0`, без визуала (`visible = false` в сцене). Используются как hook'и в пайплайн каста:

- `CollectGloveMod` — в `modify_pre_cast` ставит флаг в `info.extra_data` если у цели есть Burning; в `modify_post_cast` начисляет +5 Heat.
- `SparkGloveMod` — в `modify_pre_cast` пишет `info.extra_data["heat_cost_delta"] = -10` для `spark`.
- `HeatTouchHelmMod` — в `modify_pre_cast` дописывает в `info.effects` новый `DealDamageEffect(10, SPELL)` для `heat_touch`.
- `MaxHeatMod` — в `on_apply` поднимает `Player.overflow_threshold` на +10, в `on_remove` опускает обратно.

Шаблон: модификатор всегда фильтрует по `info.spell.id` и не трогает чужие касты.

### 4.5. Заклинания и эффекты (data-driven)

`SpellResource` (`scripts/resources/spell_resource.gd`) — это **данные**:

- `id`, `spell_name`, `description`, `icon`, `icon_active`
- `heat_cost`, `heat_reward`, `ends_turn`
- `target_type : { SINGLE_ENEMY, SINGLE_BURNABLE, ALL_BURNING, SELF, NONE }`
- `effects : Array` — массив `SpellEffectResource`

Каждый эффект — отдельный класс, унаследованный от `SpellEffectResource` и реализующий:

```gdscript
func execute(info: SpellCastInfo) -> void
```

Существующие эффекты (`scripts/resources/effects/`):

| Класс              | Что делает                                                                      |
| ------------------ | ------------------------------------------------------------------------------- |
| `DealDamageEffect` | `caster.deal_damage(target, amount, damage_type, spell.id)`                     |
| `ApplyStatusEffect`| Накладывает `status_scene` на цель (или на кастера, если `apply_to_self=true`)  |
| `IgniteEffect`     | Особый случай: накладывает `burning.tscn` на цель с `reward` стаков              |
| `CollectHeatEffect`| Снимает `BurningStatus` и возвращает кастеру тепло по коэффициенту стадии        |

**Поток каста заклинания:**

```
SpellButton.pressed_spell
    → SpellPanel._on_spell_click
    → EventBus.spell_cast(SpellResource)
    → CombatManager._on_spell_cast
        ├── SELF      → player.cast(spell, null) сразу
        └── остальные → запоминает selected_spell, ждёт target_selected

Enemy.ClickArea.pressed
    → EventBus.target_selected(enemy)
    → CombatManager._on_target_selected
    → player.cast(spell, enemy)
```

**Что делает `Combatant.cast(spell, target)`:**

1. Создаёт `SpellCastInfo` с копией `spell.effects`.
2. Прогоняет через `process_pre_cast` (статусы кастера, потом арены, потом цели). Любой статус может выставить `info.canceled = true`.
3. Если отменено — `EventBus.spell_canceled.emit(info)` и выход.
4. `_try_pay_cost(spell)` — для `Player` это списывает Heat; для `Enemy` всегда `true`.
5. Каждый эффект вызывает `effect.execute(info)`.
6. `process_post_cast` — статусам нужно знать, что каст случился.
7. `EventBus.spell_cast_resolved.emit(info)`.

> **Правило:** если хочешь добавить новое поведение заклинания — пиши **новый `SpellEffectResource`**. Не добавляй ветки `if spell.id == ...` в `CombatManager`.

**Превью каста (для UI).** Чтобы UI мог показать результирующую стоимость и урон с учётом модификаторов, не запуская реальный каст:

```
Combatant.preview_spell(spell) -> SpellCastInfo
```

Создаёт пустой `SpellCastInfo` с копией `spell.effects`, прогоняет через `statuses.process_pre_cast` кастера и арены — **без** оплаты Heat и без `effect.execute`. Возвращает информационный объект, по которому можно прочитать:

- `info.extra_data["heat_cost_delta"]` — суммарная дельта стоимости от всех модификаторов
- `info.effects` — финальный список эффектов (с возможными добавками от модификаторов)

Поверх этого:

- `SpellResource.effective_heat_cost(caster)` → `max(0, heat_cost + delta)`. `SpellButton.init` показывает на иконке именно его.
- `SpellResource.to_info_data(caster)` — в строке `Heat cost` пишет `"20 (-10)"`, в строке `Damage` — `"0 (+10)"` (база + дельта в скобках). Если модификатор отсутствует — просто база, без скобок. Дельту урона считает разностью `_sum_damage(info.effects) - _sum_damage(spell.effects)`.

> **Важно:** `preview_spell` должен оставаться чистым (без побочных эффектов). Если пишешь модификатор статуса, который трогает что-то кроме `info.extra_data` / `info.effects` в `modify_pre_cast` — это сломает превью.

### 4.6. Урон (`DamageInfo`)

`DamageInfo` (`scripts/combat/pipeline/damage_info.gd`) — RefCounted-объект, который течёт через статусы:

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

Пример: `BurningStatus.modify_outgoing_damage` режет урон ATTACK в стадии Kindling/Fading вдвое, а в Blazing — в ноль.

### 4.7. Арена (`Arena` + `ArenaResource`)

`Arena` (`scripts/combat/arena.gd`) — нода рядом с `CombatManager`, отвечает за «контекст поля боя»:

- держит свой `%StatusContainer` (статусы арены не привязаны к бойцу),
- при `enter_battle()` применяет к бойцам стартовые эффекты из `ArenaResource.battle_start_effects` и накладывает на саму арену `permanent_statuses`,
- участвует **во всех** пайплайнах урона и каста — `Combatant.cast` и `Combatant.deal_damage` явно зовут `CombatContext.arena.statuses.process_*`.

`ArenaResource` (`scripts/resources/arena_resource.gd`):

- `battle_start_effects : Array[ArenaBattleStartEntry]`
- `permanent_statuses   : Array[PackedScene]`

`ArenaBattleStartEntry` хранит `target_filter : { PLAYER, ENEMIES, ALL }` + `status_scene` + `stacks`.

### 4.8. Spellbook

`Spellbook` (`scripts/combat/spellbook.gd`) — нода-список заклинаний у каждого бойца. Любое изменение спеллбука эмитит `spellbook_changed(owner, spells)`. HUD слушает только спеллбук игрока и обновляет панель.

### 4.9. Inventory (только у игрока)

`Inventory` (`scripts/combat/inventory.gd`) живёт под Player и управляет тремя видами хранилищ:

- **Bound slots** — `BoundItemResource` модифицирует конкретное заклинание тем, что вешает на игрока `modifier_status`. Связь: `BoundItemResource.bound_spell_id == spell.id`. Слот идентифицируется этим же id (`&"collect_heat"`, `&"spark"`, `&"heat_touch"`).
- **Accessory slots** — `AccessoryResource` может добавить заклинание (`granted_spell`) и/или повесить пассивные статусы (`passive_statuses`). Слотов фиксировано 4, идентифицируются индексом.
- **Backpack** — безразмерный `Array` неактивных предметов. Идентификатор — индекс в массиве.

Inventory сам отслеживает наложенные через него статусы (через `_bound_status_refs` / `_accessory_status_refs`) и снимает их при unequip.

**Единый API перемещения:**

```
Inventory.transfer(from_kind, from_key, to_kind, to_key) -> bool
Inventory.toggle_equip(kind, key) -> bool
```

`transfer` обрабатывает три случая в одном месте:
- Свободный слот назначения → просто переносит.
- Занятый совместимый слот назначения и не-backpack источник → **swap** (предметы меняются местами).
- Занятый совместимый слот и backpack-источник → старый предмет уезжает в backpack.

Совместимость проверяется в `Inventory.is_compatible(kind, key, item)`:
- BOUND принимает только `BoundItemResource` с `bound_spell_id == key`.
- ACCESSORY принимает только `AccessoryResource`.
- BACKPACK принимает что угодно.

`toggle_equip` — короткий путь для ПКМ: из backpack → в первый подходящий пустой/совпадающий слот; из слота → в backpack.

**Сигналы:** `Inventory.changed` (локальный) + `EventBus.bound_slot_equipped/unequipped`, `EventBus.accessory_slot_equipped/unequipped` (глобальные). UI слушает локальный `changed` и полностью перерисовывает окно.

**Связь с UI заклинаний.** `Player._ready` подписывается на `Inventory.changed` и переэмитит `EventBus.spellbook_changed` с тем же списком спеллов. Это нужно, чтобы `SpellPanel` пересоздал кнопки и пересчитал effective-стоимости через `preview_spell` (см. §4.5). Спеллбук при экипировке/снятии bound-предмета не меняется — меняется набор статусов-модификаторов.

#### 4.9.1. UI инвентаря

```
InventoryButton (Button "I", top-right, рядом с LogButton)
    → InventoryWindow.open()

InventoryWindow (Control)
    Panel + CloseButton "×"
    VBox
      "Equipment"   — 3 InventorySlot (Left/Right/Head, kind=BOUND, bound_spell_id выставляется кодом)
      "Accessories" — 4 InventorySlot (kind=ACCESSORY, slot_index=0..3)
      "Backpack"    — ScrollContainer(InventoryBackpackDrop) → GridContainer → InventoryItemWidget × N
```

**`InventoryButton`** — зеркало `LogButton`, расположен слева от него (`offset_left = -112..-64`). Открывает `InventoryWindow`, прячется на время открытия, показывается обратно по сигналу `closed`.

**`InventoryWindow`** — анкорится в правый верхний угол (тот же rect, что у `CombatLog`). Координаты слотов в `.tscn` примерные — компонуется через VBox/HBox.

**`InventorySlot`** (`scripts/ui/inventory_slot.gd`) — экспортит `kind`, `bound_spell_id`/`slot_index`, `label_text`. Поведение:
- ЛКМ-drag через `_get_drag_data` (preview-иконка 48×48).
- Drop через `_can_drop_data` / `_drop_data` → `Inventory.transfer`.
- ПКМ → `Inventory.toggle_equip`.
- Hover → `CombatContext.info_panel.show_for(self, item.to_info_data())` если в слоте есть предмет.

**`InventoryItemWidget`** (`scripts/ui/inventory_item_widget.gd`) — ячейка backpack. Может быть:
- **Заполненной** (`backpack_index >= 0`, под этим индексом есть предмет): drag, ПКМ-toggle, hover-tooltip активны; иконка видна.
- **Пустой** (`backpack_index < 0` или предмета нет): только принимает drop; видит placeholder `—`; никакого drag/ПКМ/tooltip.

`InventoryWindow._rebuild_backpack` всегда рендерит `max(20, backpack.size() + 4)` ячеек, чтобы пустые места были видны и могли служить drop-целями.

**`InventoryBackpackDrop`** (`scripts/ui/inventory_backpack_drop.gd`, `extends ScrollContainer`) — fallback drop-зона. Если drop попадает на щель между виджетами или в свободное место сетки (у `BackpackGrid` `mouse_filter = IGNORE`), событие достаётся ScrollContainer'у.

#### 4.9.2. Описания предметов и tooltip

`BoundItemResource` и `AccessoryResource` имеют поле `description: String` и реализуют `to_info_data()` по тому же контракту, что спеллы и статусы (см. §4.10a):

```
BoundItemResource.to_info_data() -> {title, icon, subtitle: "Bound Item", description, lines: []}
AccessoryResource.to_info_data() -> {title, icon, subtitle: "Accessory", description, lines: []}
```

Это всё, что нужно — hover на слоте/виджете автоматически покажет popup. `InventorySlot` и `InventoryItemWidget` зовут `to_info_data()` через `has_method`-проверку, поэтому новые типы предметов получают tooltip без правок UI.

### 4.10. InfoPanel — универсальный hover-popup

`InfoPanel` (`scripts/ui/info_panel.gd`, `scenes/ui/info_panel.tscn`) — переиспользуемое всплывающее окно с информацией. Используется для арены, статусов и заклинаний.

**Контракт:**

```
info_panel.show_for(anchor: Control, data: Dictionary)
info_panel.hide_panel()
```

**Ключи `data`** (все опциональны, кроме `title`):

- `title : String` — заголовок (имя арены/статуса/заклинания)
- `icon : Texture2D` — иконка слева от заголовка
- `subtitle : String` — приглушённый подзаголовок ("Status", "Spell", "Battlefield")
- `description : String` — основной текст с автопереносом
- `lines : Array[Dictionary]` — массив `{label, value}`-строк (например, `Heat cost: 20`, `Stage: Blazing`)

**Позиционирование** (`_reposition_near`):

1. По умолчанию справа от anchor с зазором 8 px, верхняя кромка по верху anchor.
2. Если не лезет вправо → отзеркаливается влево.
3. Если не лезет вниз → подтягивается вверх (низ совпадает с низом anchor).
4. Финальный `clamp` обеих координат в пределах viewport с отступом 8 px.
5. На время репозиционирования popup невидим (один кадр), чтобы не было «прыжка».

**Стиль:** PanelContainer переопределяет `theme_override_styles/panel` непрозрачным `StyleBoxFlat` (bg `#1f1f23`, рамка `#73737f`, скругление 4 px). Это намеренно — popup должен полностью перекрывать UI под собой.

**Регистрация (важно):** в проекте только **один** `InfoPanel`, инстансится в `main.tscn`. На `_ready()` он публикует себя в `CombatContext.info_panel`; на `_exit_tree()` снимает регистрацию. Все консьюмеры (`ArenaIcon`, `SpellButton`, `StatusEffect`) обращаются к нему через `CombatContext.info_panel` — никаких `@export NodePath`.

> Используй `InfoPanel` вместо стандартных Godot-tooltip'ов везде, где нужна структурированная информация.

### 4.10a. `to_info_data()` — паттерн «toString»

`SpellResource`, `StatusEffect`, `BoundItemResource`, `AccessoryResource` определяют виртуальный метод

```
func to_info_data() -> Dictionary
```

по образцу `toString` из ООП — это контракт, который любой подкласс может расширить через `super.to_info_data()`.

**Базовые реализации:**

- `SpellResource.to_info_data(caster: Combatant = null)` — `{title: spell_name, icon, subtitle: "Spell", description, lines: [Heat cost / Heat reward / Damage / Ends turn]}`. Если передан `caster`, прогоняет `caster.preview_spell(self)` и форматирует строки `Heat cost` и `Damage` как `"<base> (<delta>)"` (база + дельта в скобках). Если дельта = 0 — пишет просто число. См. §4.5.
- `StatusEffect.to_info_data()` — `{title: display_name, subtitle: "Status", lines: [Stacks]}`. Подклассы переопределяют.
- `BoundItemResource.to_info_data()` — `{title: display_name, icon, subtitle: "Bound Item", description, lines: []}`.
- `AccessoryResource.to_info_data()` — `{title: display_name, icon, subtitle: "Accessory", description, lines: []}`.

**Текущие override'ы:**

- `BurningStatus.to_info_data()` — зовёт `super`, ставит `icon` по текущей `stage`, добавляет описание и `lines: [Stage / Stored fuel / Collect coefficient]`.
- `ShieldStatus.to_info_data()` — зовёт `super`, подставляет текстуру `icon` ноды и описание (стак-строка из базы остаётся).

**Кто рисует:**

- `SpellButton.init()` подключает `click_area.mouse_entered/exited` и зовёт `info_panel.show_for(self, spell.to_info_data(CombatContext.player))` — caster пробрасывается, чтобы tooltip показал модификаторы предметов.
- `StatusEffect._ready()` (база) — выставляет всем дочерним `Control` `mouse_filter = IGNORE` (чтобы лейбл/иконка не перехватывали hover у корня), подключает свой `mouse_entered/exited` и сам зовёт `to_info_data()`.
- `InventorySlot` / `InventoryItemWidget` — на `mouse_entered` достают предмет через `inventory.peek(...)` и зовут `info_panel.show_for(self, item.to_info_data())`. Через `has_method("to_info_data")` — для будущих типов предметов работает автоматически.

> **Правило:** новые спеллы/статусы/предметы получают tooltip автоматически. Хочешь дополнительные строки или другое описание — переопредели `to_info_data()` в подклассе и вызови `super.to_info_data()` для базы.

### 4.11. ArenaIcon

`ArenaIcon` (`scripts/ui/arena_icon.gd`, `scenes/ui/arena_icon.tscn`) — кнопка 48×48 в левом верхнем углу экрана. Сама не владеет `InfoPanel` — пользуется общим через `CombatContext.info_panel` (см. §4.10).

На `mouse_entered` строит `Dictionary` из `CombatContext.arena.def` и зовёт `info_panel.show_for(self, data)`. На `mouse_exited` — `hide_panel()`.

Если `arena.def == null` или арена пустая — popup всё равно показывается с заглушкой «Plain arena. No special effects.»

Подключается напрямую в `main.tscn` (не в `Hud`, потому что HUD прижат к низу экрана). Арена не поддерживает `to_info_data()`-паттерн (как спеллы и статусы) — данные собирает сам `ArenaIcon` из `arena.def`.

### 4.12. CombatLog + LogButton (toggleable окно)

`CombatLog` (`scripts/ui/combat_log.gd`, `scenes/ui/combat_log.tscn`) — окно лога боя.

Структура сцены:
```
CombatLog (Control, visible = false по умолчанию)
  Panel (Panel)              — фон, fill rect
  ScrollContainer            — offset_top=48, чтобы освободить место под × кнопку
    LogText (RichTextLabel, %)
  CloseButton (Button "×", %) — anchor top-right, 48×48
```

API:
- `open()` — `visible = true`
- `close()` — `visible = false`, эмитит сигнал `closed`
- Сам подписан на `EventBus.log_entry` и копит записи в `LogText` независимо от видимости.

`LogButton` (`scripts/ui/log_button.gd`, `scenes/ui/log_button.tscn`) — кнопка 48×48 в правом верхнем углу экрана (зеркало `ArenaIcon`). `@export var combat_log_path: NodePath`.

**Поведение:**
- Старт: `LogButton` виден, лог скрыт.
- Клик по `LogButton` → `combat_log.open()` + `LogButton.visible = false`.
- Клик по `×` внутри лога → `combat_log.close()` → сигнал `closed` → `LogButton.visible = true`.

**Геометрия (важно):** правая кромка лога = `vp_w - 8`, верх = `8`. `CloseButton` 48×48 в правом верхнем углу лога с нулевыми отступами от его кромок. `LogButton` 48×48 в правом верхнем углу экрана с теми же 8-px отступами. По построению они занимают **один и тот же экранный rect** — кнопка «не двигается» при открытии/закрытии, просто меняется её визуал и владелец.

Подключается в `main.tscn` (как `ArenaIcon`). `LogButton.combat_log_path = "../CombatLog"`.

### 4.13. EnemyFormation — расстановка врагов по слотам

Динамическая расстановка «N врагов в M рядов» оказалась слишком непредсказуемой для дизайна, поэтому формации **заданы как данные**: каждый бой выбирает готовую `FormationResource`, а энкаунтер решает, какие слоты занять.

**Данные:**

- `FormationSlot` (`scripts/resources/formation_slot.gd`) — `{ position: Vector2, row: int }`. `row` — для логики (AoE по ряду, line-of-sight) и z-порядка.
- `FormationResource` (`scripts/resources/formation_resource.gd`) — `{ id, display_name, slots: Array[FormationSlot] }`.

**Логика:**

`EnemyFormation` (`scripts/combat/enemy_formation.gd`, `Control + script`) — `@export var formation: FormationResource`. На `_ready`:

1. Для каждого ребёнка-`Enemy` ставит `enemy.position = formation.slots[enemy.slot_index].position`.
2. Сортирует детей `move_child` по убыванию `slot.row` — задние ряды раньше в дереве → рисуются под передними.
3. Если `slot_index` вне диапазона — `push_warning`, враг не двигается.

**Enemy:** `@export var slot_index: int = 0` — индекс слота в текущей формации.

**Готовые формации (`data/formations/`):**

| Файл | Слоты 0–2 (`row=0` или `row=1`) | Слоты 3–4 |
|---|---|---|
| `front_heavy.tres` | передний ряд (3 слота, x=0/154/308, y=100) | задний (2 слота, x=77/231, y=0) |
| `back_heavy.tres`  | задний ряд (3 слота, x=0/154/308, y=0)   | передний (2 слота, x=77/231, y=100) |

Конвенция: индексы 0–2 — основной ряд (3 слота), 3–4 — вторичный (2 слота, между ними по горизонтали).

**Пустые слоты — нормально.** Энкаунтер просто не кладёт врага в слот; layout его не использует. Текущий тестовый бой в `main.tscn` — `back_heavy` с двумя врагами в слотах 3 и 4 (передний ряд), задние три слота пустые.

**Размеры:** контейнер 458×300, исходит из `enemy_slot.tscn` 150×200 + спейсинг 4 px между слотами и 100 px между рядами по Y.

---

## 5. Главные механики

### 5.1. Heat

- Хранится в `Player.heat`, потолок `Player.max_heat` (200 по умолчанию).
- «Опасный порог» — 100. Если в конце хода `heat > 100`, игрок получает `(heat - 100)` урона типа OVERFLOW.
- `Collect Heat` — единственный «бесплатный» спелл, заканчивает ход (`ends_turn = true`).
- Стоимости списываются в `Player._try_pay_cost` (внутри `cast`), награда возвращается через `gain_heat` (например, в `CollectHeatEffect`).

### 5.2. Цикл горения

```
Smoldering → Kindling → Blazing → Fading → удаление
```

Стадии переключаются в `BurningStatus.on_turn_start` (на ходе **носителя статуса**, т.е. горящего врага).

**Эффект на исходящий ATTACK от горящего:**

| Стадия     | Множитель урона      |
| ---------- | -------------------- |
| Smoldering | 1.0 (нормально)      |
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

Особенность: `BurningStatus.stacks` зафиксирован = 1 после `on_apply`, а реальное «топливо» хранится в `stored_reward`. Повторное применение горения дописывает топливо **только в стадии Smoldering**, в остальных — отбрасывается.

---

## 6. Где что лежит

```
autoloads/
  event_bus.gd                   — глобальная шина сигналов
  combat_context.gd              — глобальный реестр player/enemies/arena

scripts/
  combat/
    combat_manager.gd            — оркестратор боя: ход игрока, ход врагов, end-of-turn
    arena.gd                     — арена + её статусы
    spellbook.gd                 — список заклинаний бойца
    status_container.gd          — управление статусами одного носителя
    status_effect.gd             — базовый класс статуса
    inventory.gd                 — слоты bound/accessory у игрока
    enemy_formation.gd           — расставляет Enemy-детей по слотам формации
    damage_context.gd            — ЛЕГАСИ, не используется текущим пайплайном
    pipeline/
      damage_info.gd             — объект, текущий через систему урона
      spell_cast_info.gd         — объект, текущий через систему каста
      status_change_request.gd   — объект, текущий через apply/remove статусов
  entities/
    combatant.gd                 — базовый класс бойца, методы cast/deal_damage
    player.gd                    — игрок: Heat, Inventory, начальные спеллы
    enemy.gd                     — враг: HP, AI, кликабельная область
  statuses/
    burning.gd                   — горение
    shield.gd                    — щит
    collect_glove_mod.gd         — +5 Heat при сборе с горящего (модификатор collect_heat)
    spark_glove_mod.gd           — -10 Heat стоимость spark
    heat_touch_helm_mod.gd       — +10 урона heat_touch
    max_heat_mod.gd              — +10 к Player.overflow_threshold
  resources/
    spell_resource.gd            — данные заклинания
    enemy_resource.gd            — данные врага
    arena_resource.gd            — данные арены
    arena_battle_start_entry.gd  — запись «кому что навесить в начале боя»
    bound_item_resource.gd       — данные bound-предмета
    accessory_resource.gd        — данные аксессуара
    formation_resource.gd        — формация: id, display_name, массив FormationSlot
    formation_slot.gd            — слот формации: position, row
    effects/
      spell_effect_resource.gd   — базовый класс эффекта
      deal_damage_effect.gd
      apply_status_effect.gd
      collect_heat_effect.gd
      ignite_effect.gd
  ui/
    hud.gd                       — корневой HUD: HP/Heat бары, оверфлоу-варн, host для статусов игрока
    spell_panel.gd               — панель заклинаний и кнопка End Turn
    spell_button.gd              — отдельная кнопка заклинания
    stat_bar.gd                  — переиспользуемый ProgressBar+label
    combat_log.gd                — окно лога боя (open/close + сигнал closed)
    info_panel.gd                — универсальный hover-popup (арена/статус/спелл/предмет)
    arena_icon.gd                — иконка арены в левом верхнем углу + свой InfoPanel
    log_button.gd                — кнопка-открывалка лога в правом верхнем углу
    inventory_button.gd          — кнопка-открывалка инвентаря (слева от LogButton)
    inventory_window.gd          — окно инвентаря (equipment + accessories + backpack)
    inventory_slot.gd            — слот для bound/accessory: drag/drop, ПКМ-toggle, hover
    inventory_item_widget.gd     — ячейка backpack (заполненная или пустая drop-цель)
    inventory_backpack_drop.gd   — fallback drop-зона на пустое место сетки backpack

data/
  spells/      spark.tres, collect_heat.tres, heat_touch.tres, shield.tres
  enemies/     skeleton.tres
  formations/  front_heavy.tres (3F+2B), back_heavy.tres (3B+2F)
  items/
    bound/        glove_collect.tres, glove_spark.tres, helm_heat_touch.tres
    accessories/  amulet_max_heat.tres

scenes/
  combat/
    combat_arena.tscn            — корневая сцена боя (контейнеры для врагов и env-объектов)
    combat_manager.tscn
    arena.tscn
    enemy_slot.tscn              — экземпляр врага: Column(NameLabel/HpBar/StatusContainer) + TextureRect + ClickArea (только под Column, чтобы не перехватывать hover статусов)
    inventory.tscn
  entities/
    player.tscn                  — игрок (StatusContainer + Spellbook + Inventory)
  statuses/
    burning.tscn                 — Icon + RewardLabel
    shield.tscn                  — Icon + ChargesLabel
    collect_glove_mod.tscn       — невидимый статус-модификатор collect_heat
    spark_glove_mod.tscn         — невидимый статус-модификатор spark
    heat_touch_helm_mod.tscn     — невидимый статус-модификатор heat_touch
    max_heat_mod.tscn            — невидимый статус, поднимающий overflow_threshold
  ui/
    hud.tscn, spell_panel.tscn, spell_button.tscn, stat_bar.tscn
    combat_log.tscn              — Control + Panel + ScrollContainer + CloseButton
    info_panel.tscn              — popup-панель (root: Control, mouse_filter=IGNORE)
    arena_icon.tscn              — Button-иконка с встроенным InfoPanel
    log_button.tscn              — Button-иконка справа сверху, открывает CombatLog
    inventory_button.tscn        — Button-иконка слева от LogButton, открывает InventoryWindow
    inventory_window.tscn        — окно инвентаря: equipment-bar / accessory-bar / backpack-grid
    inventory_slot.tscn          — Control 64×80: Bg + Icon + EmptyText + Label
    inventory_item_widget.tscn   — Control 56×56: Bg + Icon + EmptyText "—"
```

`main.tscn` инстансит `arena_icon.tscn` (top-left), `log_button.tscn` (top-right) и `inventory_button.tscn` (top-right, левее лога) рядом с `Hud`, `CombatLog` и `InventoryWindow`. `CombatLog` и `InventoryWindow` анкорятся в одинаковый rect (правый верхний угол, offset 8 px), чтобы `×` внутри окна совпадал с соответствующей открывающей кнопкой по экранным координатам.

Запланировано (ещё нет):

```
scripts/combat/heat_system.gd
scripts/combat/enemy_ai.gd
scripts/entities/env_object.gd
```

---

## 7. Поток данных по сценарию хода

```
[Начало боя]
    CombatManager._start_combat
    └── arena.enter_battle()              — навешиваются стартовые статусы
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
    pay cost (у Player списывается Heat)
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
            EventBus.turn_started(enemy)      — статусы врага обрабатывают on_turn_start (горение крутит стадии)
            enemy.take_turn(player)
            EventBus.turn_ended_by(enemy)
        EventBus.turn_started(player)
```

---

## 8. Как добавить...

### ...новое заклинание

1. Создать `data/spells/<id>.tres` со скриптом `SpellResource`.
2. Заполнить `id`, `spell_name`, `heat_cost`, `target_type`, иконки.
3. В поле `effects` собрать массив суб-ресурсов нужных эффектов.
   - Например: `[DealDamageEffect(amount=10, damage_type=SPELL), ApplyStatusEffect(status_scene=burning.tscn, stacks=15)]`.
4. Если у заклинания нестандартное поведение — сначала смотри, можно ли собрать его из существующих эффектов; если нет — пиши новый эффект (см. ниже).
5. Чтобы спелл оказался у игрока — добавь его в `Player.basic_spells` в `scenes/entities/player.tscn`. Чтобы у врага — в `EnemyResource.spells` (`data/enemies/<id>.tres`).

### ...новый эффект заклинания

1. `scripts/resources/effects/<имя>_effect.gd`:
   ```
   extends SpellEffectResource
   class_name MyNewEffect

   @export var some_param: int

   func execute(info: SpellCastInfo) -> void:
       # info.caster, info.target, info.spell, info.effects, info.extra_data
       ...
   ```
2. Эффект — это `Resource`, а не `Node`: никаких `@onready`, `_ready`. Только данные + `execute`.
3. Для побочных штук используй `EventBus.log_entry.emit(...)` и существующие методы `Combatant`.
4. Подключай эффект в любой `.tres` через `SubResource`.

### ...новый статус

1. `scripts/statuses/<имя>.gd`:
   ```
   extends StatusEffect
   class_name MyStatus

   func _init() -> void:
       id = &"my_status"
       display_name = "My Status"
       stack_mode = StackMode.INTENSITY
       priority = 5
   ```
2. Переопредели нужные хуки (`modify_outgoing_damage`, `on_turn_start`, ...).
3. Сделай сцену `scenes/statuses/<имя>.tscn`: корень со скриптом + дочерние ноды для иконки/лейбла. Внутри `_ready` или `_update_visual` обновляй визуал.
4. Включи «Unique Name in Owner» для всех `%`-нод.
5. Накладывай через `combatant.statuses.apply(preload("res://scenes/statuses/my.tscn"), 1)` или из `ApplyStatusEffect`.

### ...нового врага

1. `data/enemies/<id>.tres` — `EnemyResource` (имя, HP, base_damage, заклинания, начальные статусы).
2. По умолчанию враг будет инстансом `scenes/combat/enemy_slot.tscn` с подменённым `enemy_data` и (опционально) текстурой.
3. Для уникального поведения — наследник `Enemy` с переопределённым `take_turn(target)` либо новый кастомный AI-статус.

### ...новую формацию

1. `data/formations/<id>.tres` — `FormationResource` с массивом `FormationSlot` (каждый: `position: Vector2`, `row: int`).
2. Конвенция: чем больше `row`, тем дальше от камеры (рисуется раньше). Передний ряд — `row = 0`.
3. Никакого кода трогать не нужно — `EnemyFormation` подхватит формацию и расставит детей по `slot_index`.

### ...новый энкаунтер (бой)

1. В сцене боя положи врагов внутрь `CombatArena/EnemyFormation` (см. `main.tscn`).
2. Выстави `EnemyFormation.formation` на нужный `FormationResource`.
3. Каждому врагу-инстансу проставь `slot_index` из выбранной формации. Незанятые слоты можно оставлять пустыми.

### ...новую арену

1. `data/arenas/<id>.tres` — `ArenaResource`.
2. Заполни `battle_start_effects` (`ArenaBattleStartEntry`-записи: кого, чем, сколько стаков) и `permanent_statuses` (всегда висят на самой арене и участвуют в пайплайнах).
3. В `scenes/combat/arena.tscn` (или в боевой сцене) присвой полю `def` нужный ресурс.

### ...новый bound-предмет / аксессуар

**Bound-предмет (модифицирует конкретное заклинание):**

1. Напиши статус-модификатор: `scripts/statuses/<имя>_mod.gd` (наследник `StatusEffect`, `stack_mode = UNIQUE`, `priority = 0`). Фильтруй по `info.spell.id` и не трогай чужие касты. Хуки на выбор: `modify_pre_cast` (правит cost через `info.extra_data["heat_cost_delta"]`, добавляет эффекты в `info.effects`), `modify_post_cast`, `on_apply` / `on_remove` (для пассивных характеристик типа `overflow_threshold`).
2. Сцена `scenes/statuses/<имя>_mod.tscn` — `Control` со скриптом, `visible = false` (модификатор предмета невидим — иконку показывает сам слот инвентаря).
3. `data/items/bound/<id>.tres` (`BoundItemResource`): `id`, `display_name`, `description`, `icon`, `bound_spell_id` (id заклинания, к которому привязан слот), `modifier_status` (PackedScene из шага 2).
4. `Inventory` сам наложит/снимет статус через `equip_bound` / `unequip_bound`. Чтобы предмет был у игрока со старта — добавь в `Player.inventory.initial_bound` (или в `initial_backpack`) в `scenes/entities/player.tscn`.

**Accessory:**

1. `data/items/accessories/<id>.tres` (`AccessoryResource`): `id`, `display_name`, `description`, `icon`, опционально `granted_spell` (`SpellResource`) и/или `passive_statuses` (`Array[PackedScene]` для постоянных бафов).
2. Если нужен пассивный эффект — пиши обычный статус (`StatusEffect`), необязательно невидимый. Накладывается через `passive_statuses`.
3. Со старта — `Player.inventory.initial_accessories` (макс 4). Снятие/экипировка — через окно инвентаря (ПКМ или drag).

**Помни:**

- `description` поле обязательно — попадает в hover-tooltip предмета через `to_info_data()`.
- Превью каста (`Combatant.preview_spell`) запускает `modify_pre_cast` без оплаты Heat. Не делай в этом хуке ничего, что меняет состояние игры (логирование, изменение HP/Heat, наложение статусов и т.п.) — только мутации `info`.
- При экипировке/снятии `Inventory.changed` → `Player` переэмитит `spellbook_changed` → `SpellPanel` пересоздаст кнопки. Эффективные стоимости и tooltip пересчитаются автоматически.

### ...новый сигнал

- Если он нужен **только внутри одной сцены** — объяви его на ноде, не трогай EventBus.
- Если его слушают разные подсистемы — добавь в `autoloads/event_bus.gd`. Тип параметра в `emit` обязан совпадать с объявлением (см. lessons.md).

### ...hover-tooltip для статуса / заклинания

Уже работает автоматически через `to_info_data()` (см. §4.10a) — новые спеллы и статусы получают popup без правок UI. Хочешь свой контент — переопредели `to_info_data()` в подклассе и зови `super.to_info_data()`.

Пример (свой статус):

```
extends StatusEffect

func to_info_data() -> Dictionary:
    var data: Dictionary = super.to_info_data()
    data["icon"] = my_texture
    data["description"] = "What this status does, plain prose."
    data["lines"] = [
        {"label": "Stacks", "value": str(stacks)},
        {"label": "My field", "value": str(my_field)},
    ]
    return data
```

### ...hover-tooltip для произвольного UI-элемента

Если нужен tooltip для чего-то, не являющегося спеллом или статусом (новая иконка на HUD, env-объект и т.п.):

1. Подпишись на `mouse_entered` / `mouse_exited` нужного контрола.
2. На вход — собери `Dictionary` из ключей `title / icon / subtitle / description / lines` и вызови `CombatContext.info_panel.show_for(self, data)`.
3. На выход — `CombatContext.info_panel.hide_panel()`.
4. Не пытайся позиционировать popup сам — `InfoPanel` сам найдёт место рядом с anchor и не выйдет за viewport.

---

## 9. Нюансы и ловушки

- **`%NodeName` ломается молча**, если у ноды не включена «Unique Name in Owner». Проверь сцену перед тем, как ругаться на код.
- **`class_name` глобальный.** Переименовал класс — Godot может ещё держать старое имя в кеше; перезапусти редактор.
- **`Resource` — не нода.** Никаких `@onready`, `_ready`, `$Child`. Если нужна ссылка на сцену — `@export var scene: PackedScene` и `scene.instantiate()` в нужный момент.
- **`preload(...).instantiate()` + `init()`**: если `init` лезет в `@onready`-переменные, сначала добавь экземпляр в дерево (`add_child`), потом зови `init`.
- **Статусы — `Control`-сцены.** Они отображаются в `StatusContainer` (HBox), поэтому имеют размеры и могут влиять на layout.
- **DamageContext (`scripts/combat/damage_context.gd`) — легаси.** Текущий пайплайн использует `DamageInfo`. Не подключай старый класс к новому коду.
- **HUD не загружает спеллы.** Он только слушает `spellbook_changed`. Чтобы спелл появился у игрока — добавь его в `Player.basic_spells` (или через Inventory/Spellbook в рантайме).
- **`ClickArea` врага не должен накрывать `StatusContainer`.** В `enemy_slot.tscn` `ClickArea` (Button с `mouse_filter = STOP`) перехватывает все hover-события в своём rect. Если он накроет область статусов — `StatusEffect.mouse_entered` никогда не сработает и tooltip статуса не покажется. Текущая раскладка: `ClickArea` анкорится только под `Column` (`offset_top = 81`), а `TextureRect` имеет `mouse_filter = IGNORE`, чтобы его перекрытие с низом колонки не глотало hover статусов. Если меняешь высоту `Column` — синхронизируй `offset_top` у `ClickArea`.

---

## 10. Что **не** трогать без запроса

- Не переписывать рабочий код, если задача этого не требует.
- Не добавлять фичи сверх постановки.
- Не оставлять `# TODO` и `# add logic here` — либо делаешь, либо нет.
- Не ветвиться по `spell.id` в `CombatManager` (вместо этого — новый `SpellEffectResource`).
- Не хранить игровое состояние (HP, Heat, стадии) в UI-скриптах.
- Не обходить `Combatant.cast` / `Combatant.deal_damage` — на них висят все статусы и арена.
- Не предлагать переход на C# или смену версии Godot.