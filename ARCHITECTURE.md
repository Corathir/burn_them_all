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

`Inventory` (`scripts/combat/inventory.gd`) живёт под Player и управляет двумя видами слотов:

- **Bound slots** — `BoundItemResource` модифицирует конкретное заклинание тем, что вешает на игрока `modifier_status`. Связь: `BoundItemResource.bound_spell_id == spell.id`.
- **Accessory slots** — `AccessoryResource` может: добавить заклинание (`granted_spell`) и/или повесить пассивные статусы (`passive_statuses`).

Inventory сам отслеживает наложенные через него статусы и снимает их при unequip.

### 4.10. InfoPanel — универсальный hover-popup

`InfoPanel` (`scripts/ui/info_panel.gd`, `scenes/ui/info_panel.tscn`) — переиспользуемое всплывающее окно с информацией. Используется для арены, в будущем — для статусов и заклинаний.

**Контракт:**

```gdscript
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

> Используй `InfoPanel` вместо стандартных Godot-tooltip'ов везде, где нужна структурированная информация.

### 4.11. ArenaIcon

`ArenaIcon` (`scripts/ui/arena_icon.gd`, `scenes/ui/arena_icon.tscn`) — кнопка 48×48 в левом верхнем углу экрана. Внутри сцены лежит инстанс `InfoPanel` (поле `info_panel_path`).

На `mouse_entered` строит `Dictionary` из `CombatContext.arena.def` и зовёт `info_panel.show_for(self, data)`. На `mouse_exited` — `hide_panel()`.

Если `arena.def == null` или арена пустая — popup всё равно показывается с заглушкой «Plain arena. No special effects.»

Подключается напрямую в `main.tscn` (не в `Hud`, потому что HUD прижат к низу экрана).

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
  resources/
    spell_resource.gd            — данные заклинания
    enemy_resource.gd            — данные врага
    arena_resource.gd            — данные арены
    arena_battle_start_entry.gd  — запись «кому что навесить в начале боя»
    bound_item_resource.gd       — данные bound-предмета
    accessory_resource.gd        — данные аксессуара
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
    combat_log.gd                — лог боя
    info_panel.gd                — универсальный hover-popup (арена/статус/спелл)
    arena_icon.gd                — иконка арены в левом верхнем углу + свой InfoPanel

data/
  spells/    spark.tres, collect_heat.tres, heat_touch.tres, shield.tres
  enemies/   skeleton.tres

scenes/
  combat/
    combat_arena.tscn            — корневая сцена боя (контейнеры для врагов и env-объектов)
    combat_manager.tscn
    arena.tscn
    enemy_slot.tscn              — экземпляр врага (StatusContainer + Spellbook + ClickArea)
    inventory.tscn
  entities/
    player.tscn                  — игрок (StatusContainer + Spellbook + Inventory)
  statuses/
    burning.tscn                 — Icon + RewardLabel
    shield.tscn                  — Icon + ChargesLabel
  ui/
    hud.tscn, spell_panel.tscn, spell_button.tscn, stat_bar.tscn, combat_log.tscn
    info_panel.tscn              — popup-панель (root: Control, mouse_filter=IGNORE)
    arena_icon.tscn              — Button-иконка с встроенным InfoPanel
```

`main.tscn` инстансит `arena_icon.tscn` рядом с `Hud` и `CombatLog`.

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
   ```gdscript
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
   ```gdscript
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

### ...новую арену

1. `data/arenas/<id>.tres` — `ArenaResource`.
2. Заполни `battle_start_effects` (`ArenaBattleStartEntry`-записи: кого, чем, сколько стаков) и `permanent_statuses` (всегда висят на самой арене и участвуют в пайплайнах).
3. В `scenes/combat/arena.tscn` (или в боевой сцене) присвой полю `def` нужный ресурс.

### ...новый bound-предмет / аксессуар

- Bound: `data/items/bound/<id>.tres` (`BoundItemResource`) с `bound_spell_id` и `modifier_status`. Экипируется через `Inventory.equip_bound(spell_id, item)`.
- Accessory: `data/items/accessories/<id>.tres` (`AccessoryResource`) с `granted_spell` и/или `passive_statuses`. Экипируется через `Inventory.equip_accessory(slot_index, accessory)`.
- Снятие — `unequip_bound` / `unequip_accessory`. Inventory сам уберёт статусы и заклинания, навешенные через него.

### ...новый сигнал

- Если он нужен **только внутри одной сцены** — объяви его на ноде, не трогай EventBus.
- Если его слушают разные подсистемы — добавь в `autoloads/event_bus.gd`. Тип параметра в `emit` обязан совпадать с объявлением (см. lessons.md).

### ...hover-tooltip для статуса / заклинания / любого UI-элемента

1. Положи где-нибудь рядом инстанс `scenes/ui/info_panel.tscn` (или переиспользуй существующий, как `ArenaIcon`).
2. Подпишись на `mouse_entered` / `mouse_exited` нужного контрола.
3. На вход — собери `Dictionary` из ключей `title / icon / subtitle / description / lines` и вызови `info_panel.show_for(self, data)`.
4. Не пытайся позиционировать popup сам — `InfoPanel` сам найдёт место рядом с anchor и не выйдет за viewport.

Пример (для статуса):

```
info_panel.show_for(self, {
    "title": status.display_name,
    "icon": status_icon_texture,
    "subtitle": "Status",
    "description": "...",
    "lines": [
        {"label": "Stacks", "value": str(status.stacks)},
    ],
})
```

---

## 9. Нюансы и ловушки

- **`%NodeName` ломается молча**, если у ноды не включена «Unique Name in Owner». Проверь сцену перед тем, как ругаться на код.
- **`class_name` глобальный.** Переименовал класс — Godot может ещё держать старое имя в кеше; перезапусти редактор.
- **`Resource` — не нода.** Никаких `@onready`, `_ready`, `$Child`. Если нужна ссылка на сцену — `@export var scene: PackedScene` и `scene.instantiate()` в нужный момент.
- **`preload(...).instantiate()` + `init()`**: если `init` лезет в `@onready`-переменные, сначала добавь экземпляр в дерево (`add_child`), потом зови `init`.
- **Статусы — `Control`-сцены.** Они отображаются в `StatusContainer` (HBox), поэтому имеют размеры и могут влиять на layout.
- **DamageContext (`scripts/combat/damage_context.gd`) — легаси.** Текущий пайплайн использует `DamageInfo`. Не подключай старый класс к новому коду.
- **HUD не загружает спеллы.** Он только слушает `spellbook_changed`. Чтобы спелл появился у игрока — добавь его в `Player.basic_spells` (или через Inventory/Spellbook в рантайме).

---

## 10. Что **не** трогать без запроса

- Не переписывать рабочий код, если задача этого не требует.
- Не добавлять фичи сверх постановки.
- Не оставлять `# TODO` и `# add logic here` — либо делаешь, либо нет.
- Не ветвиться по `spell.id` в `CombatManager` (вместо этого — новый `SpellEffectResource`).
- Не хранить игровое состояние (HP, Heat, стадии) в UI-скриптах.
- Не обходить `Combatant.cast` / `Combatant.deal_damage` — на них висят все статусы и арена.
- Не предлагать переход на C# или смену версии Godot.