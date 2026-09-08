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

const ALPHA_HIT_THRESHOLD: float = 0.1

var _sprite_image: Image

const JERK_SIDE_OFFSET: float = 24.0
const JERK_RISE: float = 16.0
const JERK_DROP: float = 16.0
const JERK_SCALE_DELTA: float = 0.08
const JERK_STEP_DURATION: float = 0.06

var _sprite_base_position: Vector2
var _sprite_base_scale: Vector2
var _jerk_tween: Tween

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
    _sprite_base_position = sprite.position
    _sprite_base_scale = sprite.scale
    sprite.pivot_offset = sprite.size / 2.0
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
    if _consume_stun():
        plan_next_action()
        return
    if spellbook.spells.is_empty():
        var dmg: int = enemy_data.base_damage if enemy_data else 0
        if dmg > 0:
            var info: DamageInfo = deal_damage(target, dmg, DamageInfo.Type.ATTACK)
            if not info.canceled and info.amount > 0:
                EventBus.log_entry.emit(display_name + " attacks for " + str(info.amount) + " damage")
                _on_combat_action(target, true)
                target._on_combat_action(self, false)
    else:
        var spell: SpellResource = spellbook.spells[0]
        cast(spell, target)
    plan_next_action()

func _consume_stun() -> bool:
    for s in statuses.get_children():
        if s is StatusEffect and (s as StatusEffect).blocks_turn():
            EventBus.log_entry.emit(display_name + " is stunned and skips its turn")
            statuses.remove((s as StatusEffect).id)
            return true
    return false

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

func _on_combat_action(other: Combatant, as_actor: bool) -> void:
    if not as_actor:
        _jerk_backward()
    elif other == self:
        _jerk_self()
    else:
        _jerk_forward()

func _jerk_forward() -> void:
    _play_jerk_scaled(Vector2(0.0, JERK_DROP), 1.0 + JERK_SCALE_DELTA)

func _jerk_backward() -> void:
    _play_jerk_scaled(Vector2(0.0, -JERK_RISE), 1.0 - JERK_SCALE_DELTA)

func _jerk_self() -> void:
    _play_jerk([Vector2(-JERK_SIDE_OFFSET, 0.0), Vector2(JERK_SIDE_OFFSET, 0.0), Vector2.ZERO])

func _play_jerk(offsets: Array) -> void:
    _reset_jerk_tween()
    for offset in offsets:
        _jerk_tween.tween_property(sprite, "position", _sprite_base_position + offset, JERK_STEP_DURATION)

func _play_jerk_scaled(offset: Vector2, scale_factor: float) -> void:
    _reset_jerk_tween()
    _jerk_tween.tween_property(sprite, "position", _sprite_base_position + offset, JERK_STEP_DURATION)
    _jerk_tween.parallel().tween_property(sprite, "scale", _sprite_base_scale * scale_factor, JERK_STEP_DURATION)
    _jerk_tween.tween_property(sprite, "position", _sprite_base_position, JERK_STEP_DURATION)
    _jerk_tween.parallel().tween_property(sprite, "scale", _sprite_base_scale, JERK_STEP_DURATION)

func _reset_jerk_tween() -> void:
    if _jerk_tween and _jerk_tween.is_valid():
        _jerk_tween.kill()
    sprite.position = _sprite_base_position
    sprite.scale = _sprite_base_scale
    _jerk_tween = create_tween()

func _on_click() -> void:
    var spell: SpellResource = CombatContext.selected_spell
    if spell != null and not _is_valid_target(spell):
        return
    EventBus.target_selected.emit(self)

func _is_valid_target(spell: SpellResource) -> bool:
    for effect in spell.effects:
        if not effect.can_target(CombatContext.player, self):
            return false
    return true

## Live enemies adjacent to this one in the current formation (same row, next column).
func get_neighbors() -> Array[Enemy]:
    var formation: EnemyFormation = CombatContext.formation as EnemyFormation
    if formation == null:
        return [] as Array[Enemy]
    return formation.get_neighbors(self)

func _on_hover_enter() -> void:
    statuses.notify_hover_enter(CombatContext.player, CombatContext.selected_spell)

func _on_hover_exit() -> void:
    statuses.notify_hover_exit()

## Used by the cursor overlay to test hover against the sprite's silhouette
## (alpha channel), not its bounding rect or the wider ClickArea (which is
## deliberately larger to stay clear of StatusContainer).
func is_point_over_sprite(global_point: Vector2) -> bool:
    var rect: Rect2 = sprite.get_global_rect()
    if not rect.has_point(global_point):
        return false
    var image: Image = _get_sprite_image()
    if image == null:
        return true

    # sprite uses STRETCH_KEEP_ASPECT_CENTERED: map the point back into
    # texture space, accounting for the centered letterbox padding.
    var tex_size: Vector2 = image.get_size()
    var scale: float = min(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
    var displayed_size: Vector2 = tex_size * scale
    var offset: Vector2 = rect.position + (rect.size - displayed_size) / 2.0
    var local: Vector2 = (global_point - offset) / scale
    if local.x < 0.0 or local.y < 0.0 or local.x >= tex_size.x or local.y >= tex_size.y:
        return false
    return image.get_pixel(int(local.x), int(local.y)).a > ALPHA_HIT_THRESHOLD

func _get_sprite_image() -> Image:
    if _sprite_image == null and sprite.texture != null:
        _sprite_image = sprite.texture.get_image()
        if _sprite_image and _sprite_image.is_compressed():
            _sprite_image.decompress()
    return _sprite_image
