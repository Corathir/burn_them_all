extends Combatant

class_name Enemy

@export var enemy_data: EnemyResource
@export var slot_index: int = 0

@onready var name_label: Label = $Column/NameLabel
@onready var hp_bar: StatBar = $Column/HpBar
@onready var click_area: Button = $ClickArea

func _ready() -> void:
    super._ready()
    add_to_group("enemies")
    if not CombatContext.enemies.has(self):
        CombatContext.enemies.append(self)
    if enemy_data != null:
        init(enemy_data)
    click_area.flat = true
    click_area.pressed.connect(_on_click)
    tree_exiting.connect(_on_tree_exiting)

func _on_tree_exiting() -> void:
    CombatContext.enemies.erase(self)

func init(data: EnemyResource) -> void:
    name_label.text = data.enemy_name
    display_name = data.enemy_name
    max_hp = data.max_hp
    hp = data.max_hp
    hp_bar.init(data.max_hp, hp)
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
        return
    var spell: SpellResource = spellbook.spells[0]
    cast(spell, target)

func _on_click() -> void:
    EventBus.target_selected.emit(self)
