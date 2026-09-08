extends Combatant

class_name Enemy

const ATTACK_INTENT_ICON: Texture2D = preload("res://features/ui/intent/attack_intent.svg")

@export var enemy_data: EnemyResource
@export var slot_index: int = 0

@onready var name_label: Label = $Column/NameLabel
@onready var hp_bar: StatBar = $Column/HpBar
@onready var sprite: TextureRect = $TextureRect
@onready var click_area: Button = $ClickArea
@onready var intent_display: IntentDisplay = $Column/IntentDisplay

var next_intent: EnemyIntent

func _ready() -> void:
    super._ready()
    add_to_group("enemies")
    if not CombatContext.enemies.has(self):
        CombatContext.enemies.append(self)
    if enemy_data != null:
        init(enemy_data)
    click_area.flat = true
    click_area.pressed.connect(_on_click)
    click_area.mouse_entered.connect(_on_hover_enter)
    click_area.mouse_exited.connect(_on_hover_exit)
    tree_exiting.connect(_on_tree_exiting)
    plan_next_action()

func _on_tree_exiting() -> void:
    CombatContext.enemies.erase(self)

func init(data: EnemyResource) -> void:
    name_label.text = data.enemy_name
    display_name = data.enemy_name
    max_hp = data.max_hp
    hp = data.max_hp
    hp_bar.init(data.max_hp, hp)
    sprite.texture = data.sprite
    for spell in data.spells:
        spellbook.add_spell(spell)
    for status_scene in data.initial_statuses:
        statuses.apply(status_scene, 1)

func apply_raw_damage(amount: int) -> void:
    super.apply_raw_damage(amount)
    hp_bar.update_value(hp)

func take_turn(target: Combatant) -> void:
    if target == null or hp <= 0:
        return
    if spellbook.spells.is_empty():
        var dmg: int = enemy_data.base_damage if enemy_data else 0
        if dmg > 0:
            var info: DamageInfo = deal_damage(target, dmg, DamageInfo.Type.ATTACK)
            if not info.canceled and info.amount > 0:
                EventBus.log_entry.emit(display_name + " attacks for " + str(info.amount) + " damage")
    else:
        var spell: SpellResource = spellbook.spells[0]
        cast(spell, target)
    plan_next_action()

func plan_next_action() -> void:
    next_intent = _build_intent()
    if intent_display:
        intent_display.set_intent(next_intent)

func _build_intent() -> EnemyIntent:
    if enemy_data == null or hp <= 0:
        return null
    var intent := EnemyIntent.new()
    if spellbook.spells.is_empty():
        var dmg: int = enemy_data.base_damage
        if dmg <= 0:
            return null
        intent.kind = EnemyIntent.Kind.ATTACK
        intent.amount = dmg
        intent.icon = ATTACK_INTENT_ICON
        intent.title = display_name
        intent.description = "Strikes the player for %d damage." % dmg
        return intent
    var spell: SpellResource = spellbook.spells[0]
    intent.kind = EnemyIntent.Kind.SPELL
    intent.amount = _sum_damage(spell.effects)
    intent.icon = spell.icon if spell.icon else ATTACK_INTENT_ICON
    intent.title = spell.spell_name
    intent.description = spell.description
    return intent

func _sum_damage(effect_list: Array) -> int:
    var total: int = 0
    for effect in effect_list:
        if effect is DealDamageEffect:
            total += (effect as DealDamageEffect).amount
    return total

func _on_click() -> void:
    EventBus.target_selected.emit(self)

func _on_hover_enter() -> void:
    statuses.notify_hover_enter(CombatContext.player, CombatContext.selected_spell)

func _on_hover_exit() -> void:
    statuses.notify_hover_exit()
