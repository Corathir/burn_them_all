Готово. Вот что добавилось/поменялось:

Новые сигналы в EventBus (autoloads/event_bus.gd)
- status_applied(carrier, status), status_removed(carrier,
  status)
- damage_incoming(defender, ctx),                         
  damage_outgoing(attacker, ctx) — damage_outgoing пока не
  эмитится, появится в шаге 4 (Burning).

Новые классы
- scripts/combat/damage_context.gd — RefCounted с         
  attacker/defender/amount/source/cancelled.
- scripts/combat/statuses/status_effect.gd — базовый
  StatusEffect с _on_apply()/_on_remove() и сигналом
  charges_changed.
- scripts/combat/status_system.gd — add()/find()/has(),
  при добавлении дублирует не плодит, а складывает заряды.
- scripts/combat/statuses/shield_status.gd — подписывается
  на damage_incoming, обнуляет ctx, удаляет себя.

Сцены
- scenes/combat/status_system.tscn,
  scenes/combat/statuses/shield_status.tscn. Иконка осталась
  scenes/ui/shield_status_icon.tscn — она хранится в
  shield_status.tscn через icon_scene.
- scenes/combat/combat_manager.tscn теперь содержит
  StatusSystem рядом с BurningSystem и (пока живым)
  PlayerStatusSystem.

SpellResource
- Добавлено @export var applies_status: PackedScene.
- data/spells/shield.tres ссылается на shield_status.tscn.

CombatManager
- В _ready() добавлена группа "player_carrier".
- _cast_self_spell теперь обобщённый: if
  spell.applies_status:
  status_system.add(spell.applies_status) — никакого if
  spell_name == "Shield".
- _enemy_phase строит DamageContext, эмитит
  damage_incoming, и пишет урон только если !ctx.cancelled
  && ctx.amount > 0. Старая хардкод-проверка щита удалена.

HUD
- Подписан на status_applied/status_removed, фильтрует по
  группе player_carrier, инстанцирует status.icon_scene в
  контейнер. Старый STATUS_ICON_SCENES-словарь и обработчик
  player_status_changed удалены.

Что осталось как dead code до шага 5 (по плану)
- scripts/combat/player_status_system.gd + узел
  PlayerStatusSystem в сцене + сигнал player_status_changed
  — больше нигде не используются, удалятся вместе с
  миграцией Burning.

Что проверить в Godot перед коммитом
- Открыть shield_status.tscn и убедиться, что инспектор
  показывает заполненные status_name="Shield", icon_scene и
  max_charges=1 (после регенерации .uid редактором). Если
  поля пустые — дозаполнить вручную.
- Каст Shield → иконка появляется в HUD; следующая атака
  врага → лог "Shield blocks the attack" и иконка исчезает.