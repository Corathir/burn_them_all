# Burn Them All — боевая архитектура

Документ описывает целевую архитектуру боевой системы для применения в проекте `burn_them_all`. Приоритет отдан архитектуре (статусы как сцены на каждом бойце, pipeline-объекты с гарантированным порядком, композируемые эффекты заклинаний, инвентарь со слотами, арена с глобальными модификаторами). Существующие конвенции из `CLAUDE.md` (централизованные системы, Enemy как visual-only) **не сохраняются** там, где противоречат целевой архитектуре. Имена и пути файлов проекта используются как привязка.

Godot 4.6.1, GDScript. Стиль файлов: snake_case, имена нод — PascalCase, уникальный доступ через `%`.

---

## Сводка изменений в существующем коде

- **`BurningSystem`** упраздняется как отдельная централизованная система. Горение становится одним из статусов с особой логикой стадий, через общий механизм `StatusContainer`.
- **`CombatManager`** перестаёт хранить состояние игрока (`player_hp`, `current_heat`). Эти поля переезжают в новый класс `Player`. CombatManager остаётся координатором: запускает бой, ведёт фазы хода, владеет `arena`, отправляет события.
- **`Enemy`** получает `StatusContainer` дочерним узлом, методы `deal_damage` / `apply_raw_damage`, ссылку на свой `Spellbook`. Принцип «Enemy — visual only» отменяется: бойцы (и игрок, и враг) являются логическими сущностями с визуальной частью.
- **`SpellResource`** расширяется массивом `effects: Array[SpellEffectResource]`. Существующие заклинания (`Spark`, `HeatTouch`, `CollectHeat`) переписываются как композиции эффектов. Старые поля (`heat_cost`, `ends_turn`, `target_type`) сохраняются.
- **`BurnStatusIcon`** заменяется сценой статуса горения (см. блок 4).
- **`Hud`** перестаёт сам preload'ить заклинания. Получает их через `EventBus.spells_loaded`. UI остаётся реактивным к сигналам.

---

## 1. Глобальный контекст

### EventBus (расширение `autoloads/event_bus.gd`)

Существующие сигналы (`spell_selected`, `spell_cast`, `target_selected`, `heat_changed`, `burn_stage_changed`, `turn_ended`, `combat_finished`, `log_entry`, `state_changed`, `spell_resolved`, `combat_initialized`) сохраняются на время миграции. После миграции `burn_stage_changed` удаляется (заменяется на `status_stacks_changed`).

Добавляются:

```gdscript
# combat lifecycle
signal turn_started(actor: Combatant)
signal turn_ended_by(actor: Combatant)        # rename of existing 'turn_ended' once migration done
signal spells_loaded(spells: Array[SpellResource])
signal spellbook_changed(owner: Combatant, spells: Array[SpellResource])

# damage and casts
signal damage_dealt(info: DamageInfo)
signal spell_cast_resolved(info: SpellCastInfo)
signal spell_canceled(info: SpellCastInfo)

# generic statuses
signal status_applied(host: Combatant, status: StatusEffect)
signal status_removed(host: Combatant, status: StatusEffect)
signal status_stacks_changed(host: Combatant, status: StatusEffect, delta: int)

# inventory
signal bound_slot_equipped(spell_id: StringName, item: BoundItemResource)
signal bound_slot_unequipped(spell_id: StringName)
signal accessory_slot_equipped(slot_index: int, accessory: AccessoryResource)
signal accessory_slot_unequipped(slot_index: int)
```

### CombatContext (новый autoload)

Хранит ссылки на текущий бой. Pipeline'ы достают через него арену.

```gdscript
# autoloads/combat_context.gd
extends Node

var player: Player
var enemies: Array[Enemy] = []
var arena: Arena

func all_combatants() -> Array[Combatant]:
    var result: Array[Combatant] = [player]
    result.append_array(enemies)
    return result
```

Регистрируется в `project.godot` как `CombatContext`.

---

## 2. Pipeline-объекты (RefCounted)

Расположение: `scripts/combat/pipeline/`. Это запросы, мутируемые модификаторами в гарантированном порядке. Не Resource (не нужны в редакторе), не Node.

```gdscript
# scripts/combat/pipeline/damage_info.gd
class_name DamageInfo extends RefCounted

enum Type { ATTACK, SPELL, BURNING, OVERFLOW, PURE }

var amount: int
var type: Type
var source: Combatant
var target: Combatant
var ability_id: StringName
var canceled: bool = false
```

```gdscript
# scripts/combat/pipeline/spell_cast_info.gd
class_name SpellCastInfo extends RefCounted

var spell: SpellResource
var caster: Combatant
var target: Combatant            # may be null for SELF / NONE target_type
var effects: Array               # Array[SpellEffectResource], shallow copy of spell.effects
var canceled: bool = false
var extra_data: Dictionary = {}
```

```gdscript
# scripts/combat/pipeline/status_change_request.gd
class_name StatusChangeRequest extends RefCounted

enum Kind { APPLY, REMOVE, MODIFY_STACKS }

var kind: Kind
var host: Combatant
var status_id: StringName
var status_scene: PackedScene    # for APPLY
var stacks: int = 1              # for APPLY / MODIFY_STACKS
var canceled: bool = false
```

---

## 3. Статусы (как сцены, на каждом бойце)

### Базовый класс

Расположение: `scripts/combat/status_effect.gd`. Сцены конкретных статусов — в `scenes/statuses/<id>.tscn`, скрипты — в `scripts/statuses/<id>.gd`.

Корень сцены статуса — `Control` (вписывается в существующий `EnemySlot/Column/StatusEffects` HBoxContainer и в новый аналогичный контейнер у игрока).

```gdscript
# scripts/combat/status_effect.gd
class_name StatusEffect extends Control

enum StackMode { DURATION, INTENSITY, REFRESH, UNIQUE }

@export var id: StringName
@export var display_name: String
@export var stack_mode: StackMode = StackMode.INTENSITY
@export var priority: int = 0

var stacks: int = 1
var host: Combatant

# lifecycle
func on_apply() -> void: pass
func on_remove() -> void: pass
func on_stacks_changed(_delta: int) -> void: pass

# turn hooks
func on_turn_start() -> void: pass
func on_turn_end() -> void: pass

# pipeline modifiers
func modify_outgoing_damage(_info: DamageInfo) -> void: pass
func modify_incoming_damage(_info: DamageInfo) -> void: pass
func on_damage_dealt(_info: DamageInfo) -> void: pass
func on_damage_taken(_info: DamageInfo) -> void: pass
func modify_pre_cast(_info: SpellCastInfo) -> void: pass
func modify_pre_cast_incoming(_info: SpellCastInfo) -> void: pass
func modify_post_cast(_info: SpellCastInfo) -> void: pass
func intercept_status_change(_req: StatusChangeRequest) -> void: pass
```

Каждый конкретный статус — отдельная сцена в `scenes/statuses/`, корневой `Control` со скриптом-наследником `StatusEffect`. Внутри: `Icon (TextureRect)`, опционально `StackLabel (Label)`, опционально `AnimationPlayer` для появления/исчезновения.

### StatusContainer

Расположение: `scripts/combat/status_container.gd`. Это `Control` (HBoxContainer-подобный layout) — служит и логическим менеджером, и визуальным якорем для иконок. Один на каждом бойце как ребёнок.

```gdscript
class_name StatusContainer extends HBoxContainer

func apply(scene: PackedScene, stacks: int = 1) -> void:
    # 1. build StatusChangeRequest
    # 2. run intercept_status_change on own statuses + arena statuses
    # 3. if not canceled: stack on existing instance (by id) per stack_mode,
    #    or instantiate scene and add_child
    pass

func remove(id: StringName) -> void: ...
func remove_stack(id: StringName, amount: int = 1) -> void: ...
func find(id: StringName) -> StatusEffect: ...

# pipeline routing — called from Combatant
func process_outgoing_damage(info: DamageInfo) -> void: ...
func process_incoming_damage(info: DamageInfo) -> void: ...
func process_pre_cast(info: SpellCastInfo) -> void: ...
func process_pre_cast_incoming(info: SpellCastInfo) -> void: ...
func process_post_cast(info: SpellCastInfo) -> void: ...
func process_status_change(req: StatusChangeRequest) -> void: ...

# turn hooks routing
func _ready() -> void:
    EventBus.turn_started.connect(_on_turn_started)
    EventBus.turn_ended_by.connect(_on_turn_ended)

func _on_turn_started(actor: Combatant) -> void:
    if actor != get_parent(): return
    for s in get_children().duplicate():
        s.on_turn_start()
```

Правила:

- **Дети контейнера = активные статусы**. Это даёт автоматический cleanup и визуализацию.
- **Сортировка по `priority`** в pipeline-методах (используй кэш, инвалидируй на add/remove).
- **Безопасная итерация**: `get_children().duplicate()` в местах, где статус может удалить сам себя.
- **Стакание**: `apply()` ищет ребёнка с тем же `id`, если есть — применяет `stack_mode`, не инстанцирует новую сцену.
- **Изменения статусов через `StatusChangeRequest`**: позволяет статусам арены блокировать наложение/снятие/стак конкретных эффектов на конкретных целях.

### Особый случай: Burning

Горение — **один статус `BurningStatus`** с внутренним полем `stage` (enum `SMOLDERING/KINDLING/BLAZING/FADING`) и `stored_reward`. Сцена одна, иконка и текст обновляются при смене стадии. Вся механика горения остаётся в одном файле — это сохраняет читаемость, ради которой раньше существовала отдельная `BurningSystem`, без изоляции от общего фреймворка.

```gdscript
# scripts/statuses/burning.gd
class_name BurningStatus extends StatusEffect

enum Stage { SMOLDERING, KINDLING, BLAZING, FADING }

const STAGE_ICONS: Dictionary = { ... }   # one texture per stage
const COLLECT_COEFFICIENTS: Dictionary = {
    Stage.SMOLDERING: 0.0, Stage.KINDLING: 0.5,
    Stage.BLAZING: 1.5,    Stage.FADING: 1.0,
}

var stage: Stage = Stage.SMOLDERING
var stored_reward: int = 0

func _init() -> void:
    id = &"burning"
    stack_mode = StackMode.UNIQUE   # only one burning per host

func on_apply() -> void:
    stored_reward = stacks
    stacks = 1
    _update_visual()

func on_stacks_changed(delta: int) -> void:
    # apply() called again on existing instance — feeding fuel
    if stage == Stage.SMOLDERING:
        stored_reward += delta
        _update_visual()
    # later stages: ignore (matches existing ignite semantics)

func on_turn_start() -> void:
    match stage:
        Stage.SMOLDERING: _set_stage(Stage.KINDLING)
        Stage.KINDLING:   _set_stage(Stage.BLAZING)
        Stage.BLAZING:    _set_stage(Stage.FADING)
        Stage.FADING:     host.statuses.remove(id)

func collect() -> int:
    return int(stored_reward * COLLECT_COEFFICIENTS.get(stage, 0.0))

# burning enemies attack weaker
func modify_outgoing_damage(info: DamageInfo) -> void:
    if info.type != DamageInfo.Type.ATTACK: return
    match stage:
        Stage.KINDLING, Stage.FADING: info.amount = int(info.amount * 0.5)
        Stage.BLAZING: info.amount = 0
```

Ключевые моменты:

- **`stack_mode = UNIQUE`** — повторный `apply()` не плодит экземпляров, а попадает в `on_stacks_changed(delta)`, где топливо добавляется только в Smoldering.
- **Модификатор на стороне источника**: горящий враг сам урезает свой урон через `modify_outgoing_damage`. Логика `_enemy_phase` про множители Kindling/Fading/Blazing удаляется — переезжает сюда.
- **`CollectHeatEffect`** ищет статус через `target.statuses.find(&"burning")`, читает `.collect()`, затем `target.statuses.remove(&"burning")`.
- **Анимации переходов** — `AnimationPlayer` внутри сцены статуса, `_set_stage` запускает нужную анимацию. Полностью локально, без участия общей системы.

---

## 4. Заклинания

### SpellResource (расширение `scripts/resources/spell_resource.gd`)

Существующие поля сохраняются: `spell_name`, `heat_cost`, `heat_reward`, `ends_turn`, `description`, `target_type`, `icon`, `icon_active`. Добавляется:

```gdscript
@export var id: StringName
@export var effects: Array[SpellEffectResource]
```

Поле `heat_reward` после миграции существующих заклинаний на эффекты становится излишним — `Spark` использует `IgniteEffect(amount=20)`, `HeatTouch` — пустой массив (только тратит heat), `CollectHeat` — `CollectHeatEffect()`. Поле не удаляется в первой итерации, чтобы не ломать существующие .tres.

### SpellEffectResource и наследники

Расположение: `scripts/resources/effects/`. Базовый класс + конкретные.

```gdscript
# scripts/resources/effects/spell_effect_resource.gd
class_name SpellEffectResource extends Resource
func execute(_info: SpellCastInfo) -> void: pass
```

```gdscript
# scripts/resources/effects/deal_damage_effect.gd
class_name DealDamageEffect extends SpellEffectResource
@export var amount: int
@export var damage_type: DamageInfo.Type

func execute(info: SpellCastInfo) -> void:
    info.caster.deal_damage(info.target, amount, damage_type, info.spell.id)
```

```gdscript
# scripts/resources/effects/apply_status_effect.gd
class_name ApplyStatusEffect extends SpellEffectResource
@export var status_scene: PackedScene
@export var stacks: int = 1
@export var apply_to_self: bool = false

func execute(info: SpellCastInfo) -> void:
    var t: Combatant = info.caster if apply_to_self else info.target
    t.statuses.apply(status_scene, stacks)
```

```gdscript
# scripts/resources/effects/ignite_effect.gd
class_name IgniteEffect extends SpellEffectResource
@export var reward: int

func execute(info: SpellCastInfo) -> void:
    var burning_scene: PackedScene = preload("res://scenes/statuses/burning.tscn")
    info.target.statuses.apply(burning_scene, reward)
```

```gdscript
# scripts/resources/effects/collect_heat_effect.gd
class_name CollectHeatEffect extends SpellEffectResource

func execute(info: SpellCastInfo) -> void:
    var burning: BurningStatus = info.target.statuses.find(&"burning") as BurningStatus
    if not burning:
        EventBus.log_entry.emit("Cannot collect from " + info.target.display_name)
        return
    var heat: int = burning.calculate_collect_value()
    info.caster.gain_heat(heat)
    info.target.statuses.remove(&"burning")
    EventBus.log_entry.emit(info.spell.spell_name + " → " + info.target.display_name + " (+" + str(heat) + " Heat)")
```

Прочие классы (`HealEffect`, `ConditionalEffect`, `ChainTargetsEffect`) добавляются по мере необходимости — каждый реализует `execute`.

### Адаптация существующих .tres

`data/spells/spark.tres` → добавить `id = &"spark"`, `effects = [IgniteEffect(reward=20)]`.
`data/spells/heat_touch.tres` → `id = &"heat_touch"`, `effects = []`.
`data/spells/collect_heat.tres` → `id = &"collect_heat"`, `effects = [CollectHeatEffect()]`.

Будущие заклинания (атаки) — добавляют `DealDamageEffect`, `ApplyStatusEffect` и так далее, без правок кода.

### Spellbook

Расположение: `scripts/combat/spellbook.gd`. Node, дочерний к `Combatant`.

```gdscript
class_name Spellbook extends Node

var spells: Array[SpellResource] = []

func add_spell(spell: SpellResource) -> void: ...
func remove_spell(spell: SpellResource) -> void: ...
func has_spell(id: StringName) -> bool: ...
```

При изменении эмитится `EventBus.spellbook_changed(owner, spells)`. UI (`SpellPanel`) подписывается и пересоздаёт кнопки. Это заменяет существующий `Hud._ready` preload трёх .tres'ов: теперь `Player._ready` заполняет свой `Spellbook` базовыми заклинаниями из своего шаблона, и `Hud` получает их через сигнал.

---

## 5. Бойцы

### Combatant (базовый класс)

Расположение: `scripts/entities/combatant.gd`. Общая логика игрока и врага: HP, Heat (опционально, не у всех — Heat только у игрока в этой игре), `StatusContainer`, `Spellbook`, методы `deal_damage` / `apply_raw_damage` / `cast`. Корень — `Control` (как существующий `Enemy`).

```gdscript
class_name Combatant extends Control

@export var max_hp: int = 30
@export var display_name: String

var hp: int

@onready var statuses: StatusContainer = %StatusContainer
@onready var spellbook: Spellbook = %Spellbook

func _ready() -> void:
    hp = max_hp

func deal_damage(target: Combatant, base: int, type: int, ability_id: StringName = &"") -> void:
    var info := DamageInfo.new()
    info.amount = base
    info.type = type
    info.source = self
    info.target = target
    info.ability_id = ability_id
    
    statuses.process_outgoing_damage(info)
    CombatContext.arena.statuses.process_outgoing_damage(info)
    target.statuses.process_incoming_damage(info)
    CombatContext.arena.statuses.process_incoming_damage(info)
    
    if info.canceled: return
    target.apply_raw_damage(info.amount)
    EventBus.damage_dealt.emit(info)
    
    for s in statuses.get_children(): s.on_damage_dealt(info)
    for s in target.statuses.get_children(): s.on_damage_taken(info)

func cast(spell: SpellResource, target: Combatant) -> bool:
    var info := SpellCastInfo.new()
    info.spell = spell
    info.caster = self
    info.target = target
    info.effects = spell.effects.duplicate()
    
    statuses.process_pre_cast(info)
    CombatContext.arena.statuses.process_pre_cast(info)
    if target: target.statuses.process_pre_cast_incoming(info)
    
    if info.canceled:
        EventBus.spell_canceled.emit(info)
        return false
    
    if not _try_pay_cost(spell): return false
    
    for effect in info.effects: effect.execute(info)
    
    statuses.process_post_cast(info)
    CombatContext.arena.statuses.process_post_cast(info)
    EventBus.spell_cast_resolved.emit(info)
    return true

func apply_raw_damage(amount: int) -> void:
    hp = max(0, hp - amount)
    # subclass emits its own UI signal

func _try_pay_cost(_spell: SpellResource) -> bool:
    return true   # overridden in Player (subtracts heat)
```

### Player

Расположение: `scripts/entities/player.gd`. Наследует `Combatant`. Добавляет Heat, Inventory, Spellbook initialization.

```gdscript
class_name Player extends Combatant

@export var max_heat: int = 200
@export var initial_heat: int = 50
@export var basic_spells: Array[SpellResource]   # Spark, HeatTouch, CollectHeat — set in scene

var heat: int

@onready var inventory: Inventory = %Inventory

func _ready() -> void:
    super._ready()
    heat = initial_heat
    for spell in basic_spells:
        spellbook.add_spell(spell)
    EventBus.combat_initialized.emit(max_hp, hp, max_heat, heat)
    EventBus.spellbook_changed.emit(self, spellbook.spells)

func _try_pay_cost(spell: SpellResource) -> bool:
    if heat < spell.heat_cost: return false
    heat -= spell.heat_cost
    EventBus.heat_changed.emit(heat)
    return true

func gain_heat(amount: int) -> void:
    heat += amount
    EventBus.heat_changed.emit(heat)

func apply_raw_damage(amount: int) -> void:
    super.apply_raw_damage(amount)
    EventBus.player_damaged.emit(amount)
```

Сцена `scenes/entities/player.tscn` — корневой `Control` (или невидимый Node, если игрок не отображается на арене), дочерние: `StatusContainer` (для статусов игрока — UI-якорь визуально живёт в HUD, контейнер reparent'ит туда детей), `Spellbook`, `Inventory`.

### Enemy (адаптация существующего `scripts/entities/enemy.gd`)

`Enemy extends Combatant`. Существующая сцена `scenes/combat/enemy_slot.tscn` дополняется:
- `StatusContainer` как ребёнок (`Column/StatusEffects` HBoxContainer переиспользуется как StatusContainer — меняется тип ноды на `StatusContainer extends HBoxContainer`).
- `Spellbook` как ребёнок.

Существующее поле `current_hp` становится `hp` (наследуется от `Combatant`). `enemy_data: EnemyResource` сохраняется как источник параметров (см. ниже). Метод `get_damage(damage)` заменяется на `apply_raw_damage(amount)` из базового класса. Сигнал `target_selected` остаётся.

`EnemyResource` расширяется: добавляются `id`, `spells: Array[SpellResource]`, `initial_statuses: Array[PackedScene]`, `ai_script: GDScript` (или enum `AIBehavior`). При спавне `Enemy._ready()` заполняет `spellbook.spells = enemy_data.spells` и применяет initial статусы.

### CombatManager (адаптация)

Перестаёт хранить `player_hp`, `current_heat`, `selected_spell` напрямую. Остаётся:

- Координатор фаз: `start_combat`, `_end_player_turn`, `_enemy_phase`.
- Хранит `selected_spell` для UI-flow выбора цели.
- Не подписывается на `target_selected` для применения урона — вместо этого зовёт `CombatContext.player.cast(selected_spell, target)`.
- `_enemy_phase` для каждого `enemy in CombatContext.enemies` зовёт его AI: `enemy.take_turn(CombatContext.player)`, что внутри использует `enemy.cast(...)`.
- На `turn_started` / `turn_ended_by` эмиттит сигналы — `StatusContainer` всех бойцов на них реагируют.

Heat overflow — больше не считается в CombatManager. Это делает `OverflowStatus` на игроке (или эффект в `_end_player_turn` через `player.deal_damage(player, overflow, OVERFLOW)`, без статуса).

---

## 6. Инвентарь

Расположение: `scripts/combat/inventory.gd`, сцены — `scenes/combat/inventory.tscn`. Дочерний узел `Player`.

### Структура

```
Inventory (Node)
├── BoundSlots (Node)
│   ├── Slot_Spark         (BoundSlot)
│   ├── Slot_HeatTouch     (BoundSlot)
│   └── Slot_CollectHeat   (BoundSlot)
└── AccessorySlots (Node)
    ├── Accessory0         (AccessorySlot)
    ├── Accessory1         (AccessorySlot)
    └── Accessory2         (AccessorySlot)
```

### BoundItemResource

Расположение: `scripts/resources/bound_item_resource.gd`. Жёстко привязан к одному базовому заклинанию.

```gdscript
class_name BoundItemResource extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var bound_spell_id: StringName        # which basic spell this fits
@export var modifier_status: PackedScene      # status applied to player while equipped
```

### AccessoryResource

```gdscript
class_name AccessoryResource extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var granted_spell: SpellResource           # the new spell this unlocks
@export var passive_statuses: Array[PackedScene] = []
```

### Inventory API

```gdscript
class_name Inventory extends Node

func equip_bound(spell_id: StringName, item: BoundItemResource) -> bool: ...
func unequip_bound(spell_id: StringName) -> void: ...
func equip_accessory(slot_index: int, accessory: AccessoryResource) -> bool: ...
func unequip_accessory(slot_index: int) -> void: ...
```

Логика:
- `equip_bound` — валидирует `item.bound_spell_id == spell_id`, спавнит `modifier_status`, зовёт `player.statuses.apply(...)`. Эмиттит `EventBus.bound_slot_equipped`.
- `equip_accessory` — добавляет `accessory.granted_spell` в `player.spellbook` (что вызывает `spellbook_changed` → перерисовка `SpellPanel`). Применяет `passive_statuses`.
- При снятии — обратные операции по сохранённым ссылкам в самих слотах.

### Модификаторы (на примере)

```gdscript
# scripts/statuses/piercing_fangs.gd — example modifier from a bound slot item
class_name PiercingFangs extends StatusEffect

@export var bound_spell_id: StringName   # set in scene inspector

func modify_outgoing_damage(info: DamageInfo) -> void:
    if info.ability_id != bound_spell_id: return
    info.amount += 3

func modify_pre_cast(info: SpellCastInfo) -> void:
    if info.spell.id != bound_spell_id: return
    info.effects.append(_build_extra_burn_effect())
```

---

## 7. Арена

Расположение: `scripts/combat/arena.gd`, сцена `scenes/combat/arena.tscn`. Заменяет существующую `combat_arena.tscn` или встраивается в неё. `CombatContext.arena` ссылается на этот узел.

Арена — `Combatant`-подобный носитель `StatusContainer`, но без HP/Heat и без Spellbook. Через её StatusContainer проходят все pipeline-вызовы каждого бойца (см. `Combatant.deal_damage` и `Combatant.cast`).

```gdscript
class_name Arena extends Node

@export var def: ArenaResource

@onready var statuses: StatusContainer = %StatusContainer

func enter_battle() -> void:
    for entry in def.battle_start_effects:
        for combatant in _resolve_targets(entry.target_filter):
            combatant.statuses.apply(entry.status_scene, entry.stacks)
    for s in def.permanent_statuses:
        statuses.apply(s)

func _resolve_targets(filter: int) -> Array[Combatant]:
    match filter:
        ArenaBattleStartEntry.TargetFilter.PLAYER: return [CombatContext.player]
        ArenaBattleStartEntry.TargetFilter.ENEMIES: return CombatContext.enemies as Array[Combatant]
        ArenaBattleStartEntry.TargetFilter.ALL: return CombatContext.all_combatants()
    return []
```

```gdscript
# scripts/resources/arena_resource.gd
class_name ArenaResource extends Resource

@export var id: StringName
@export var display_name: String
@export var battle_start_effects: Array[ArenaBattleStartEntry]
@export var permanent_statuses: Array[PackedScene]
```

```gdscript
# scripts/resources/arena_battle_start_entry.gd
class_name ArenaBattleStartEntry extends Resource

enum TargetFilter { PLAYER, ENEMIES, ALL }
@export var target_filter: TargetFilter
@export var status_scene: PackedScene
@export var stacks: int = 1
```

Арена сама **не имеет особых хуков**. Она использует тот же `StatusContainer` и тот же `StatusEffect`-интерфейс. Её статусы пишутся идентично статусам бойцов, просто помещаются в её контейнер.

`CombatManager.start_combat()` инстанцирует арену из её `ArenaResource`, вызывает `arena.enter_battle()`.

---

## 8. Поток обработки

### Урон

```
source.statuses.process_outgoing_damage(info)
    ↓
CombatContext.arena.statuses.process_outgoing_damage(info)
    ↓
target.statuses.process_incoming_damage(info)
    ↓
CombatContext.arena.statuses.process_incoming_damage(info)
    ↓
if not canceled: target.apply_raw_damage(info.amount)
    ↓
post-hooks: on_damage_dealt / on_damage_taken on all relevant statuses
```

### Каст

```
caster.statuses.process_pre_cast(info)
    ↓
CombatContext.arena.statuses.process_pre_cast(info)
    ↓
target.statuses.process_pre_cast_incoming(info)         # if target != null
    ↓
if not canceled: pay cost, then execute info.effects in order
    ↓
caster.statuses.process_post_cast(info)
    ↓
CombatContext.arena.statuses.process_post_cast(info)
```

### Изменение статусов

```
StatusContainer.apply / remove / remove_stack
    ↓
build StatusChangeRequest
    ↓
host.statuses.process_status_change(req)
    ↓
CombatContext.arena.statuses.process_status_change(req)
    ↓
if not canceled: actually mutate
```

---

## 9. UI обновления

### Hud

`Hud._ready` перестаёт preload'ить три заклинания. Подписывается на `EventBus.spellbook_changed(owner, spells)` и для `owner == CombatContext.player` зовёт `spell_panel.load_spells(spells)`. Также добавляется новый дочерний узел `PlayerStatusEffects (HBoxContainer)` в `VBoxContainer` — туда reparent'ятся иконки статусов игрока (контейнер игрока физически живёт в `Player`, но детей-иконок отображает через `Hud` через явный reparent при `add_child` или через ссылку anchor'а).

### SpellPanel

Существующая логика выбора и подсветки кнопок сохраняется. Метод `load_spells` теперь может вызываться повторно (при экипировке аксессуара) — должен корректно очищать старые кнопки и пересоздавать.

### Иконки статусов

Иконки статусов на враге уже отображаются через существующий `EnemySlot/Column/StatusEffects` HBoxContainer — он становится `StatusContainer` (тип меняется на `extends HBoxContainer`). Сцены статусов (`scenes/statuses/*.tscn`) — `Control` с иконкой и стак-меткой, как сейчас `BurnStatusIcon`.

---

## 10. Точки расширения

После этой адаптации новый контент добавляется без изменений в боевой системе:

- **Новое базовое заклинание** — `SpellResource.tres` с массивом `effects` + регистрация в `Player.basic_spells` + кнопка в UI (создаётся автоматически через `spellbook_changed`).
- **Новое аксессуарное заклинание** — `SpellResource.tres` + `AccessoryResource.tres` со ссылкой на него.
- **Новый предмет в bound-слот** — `BoundItemResource.tres` + сцена статуса-модификатора (если нужна нестандартная логика — новый `.gd` файл, наследующий `StatusEffect`).
- **Новый статус** — сцена в `scenes/statuses/` со скриптом-наследником `StatusEffect`, переопределяющим нужные хуки.
- **Новая арена** — `ArenaResource.tres` со ссылками на сцены статусов.
- **Новый эффект заклинания** (например, «лечение от нанесённого урона») — новый класс `SpellEffectResource`, потом используется в любых заклинаниях через инспектор.

Если для нового контента приходится править `Combatant` / `StatusContainer` / pipeline'ы — это сигнал, что нужная категория хука отсутствует. Добавляется как пустой метод в `StatusEffect` плюс вызов в нужном месте контейнера. Существующие статусы при этом не ломаются.

---

## Порядок миграции (для справки исполнителю)

Порядок выполнения шагов остаётся за исполнителем. Сводный список затронутых файлов:

**Создаются**:
- `autoloads/combat_context.gd`
- `scripts/combat/pipeline/{damage_info, spell_cast_info, status_change_request}.gd`
- `scripts/combat/{status_effect, status_container, spellbook, inventory, arena}.gd`
- `scripts/entities/{combatant, player}.gd`
- `scripts/resources/{bound_item_resource, accessory_resource, arena_resource, arena_battle_start_entry}.gd`
- `scripts/resources/effects/{spell_effect_resource, deal_damage_effect, apply_status_effect, ignite_effect, collect_heat_effect}.gd`
- `scripts/statuses/burning.gd` и сцена `scenes/statuses/burning.tscn`
- `scenes/entities/player.tscn`, `scenes/combat/inventory.tscn`, `scenes/combat/arena.tscn`

**Изменяются**:
- `autoloads/event_bus.gd` (новые сигналы)
- `project.godot` (autoload `CombatContext`)
- `scripts/resources/spell_resource.gd` (поле `id`, `effects`)
- `scripts/resources/enemy_resource.gd` (поля `id`, `spells`, `initial_statuses`, AI)
- `scripts/entities/enemy.gd` (наследует `Combatant`)
- `scenes/combat/enemy_slot.tscn` (StatusContainer вместо StatusEffects HBox, Spellbook ребёнком)
- `scripts/combat/combat_manager.gd` (убирает player_hp/heat, делегирует Player'у)
- `scripts/ui/hud.gd` (через `spellbook_changed` вместо preload)
- `data/spells/*.tres` (добавить `id`, `effects`)

**Удаляются** (после полной миграции):
- `scripts/combat/burning_system.gd`
- `scenes/combat/burning_system.tscn`
- `scripts/ui/burn_status_icon.gd` (заменяется сценой `scenes/statuses/burning.tscn`)
- `scenes/ui/burn_status_icon.tscn`
- сигнал `burn_stage_changed` в `EventBus`

`CombatManager._enemy_phase` существующий код (умножение урона на 0.5 при KINDLING/FADING, 0 при BLAZING) выкидывается — эта логика переезжает в хуки `BurningStatus.modify_outgoing_damage` (на стороне самого врага: его атака уменьшается, потому что он горит).
