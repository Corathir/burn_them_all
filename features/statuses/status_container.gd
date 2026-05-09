extends HBoxContainer

class_name StatusContainer

var _cached_host: Node

func _ready() -> void:
    _cached_host = _resolve_host()
    EventBus.turn_started.connect(_on_turn_started)
    EventBus.turn_ended_by.connect(_on_turn_ended)

func _resolve_host() -> Node:
    var node: Node = get_parent()
    while node:
        if node is Combatant or (node.has_method("get") and node.get("is_arena") == true):
            return node
        node = node.get_parent()
    return get_parent()

func apply(scene: PackedScene, stacks: int = 1) -> StatusEffect:
    var probe: StatusEffect = scene.instantiate()
    var status_id: StringName = probe.id
    var existing: StatusEffect = find(status_id)

    var req := StatusChangeRequest.new()
    req.host = _host()
    req.status_id = status_id
    req.status_scene = scene
    req.stacks = stacks
    req.negative = probe.negative
    req.kind = StatusChangeRequest.Kind.APPLY if existing == null else StatusChangeRequest.Kind.MODIFY_STACKS
    process_status_change(req)
    if CombatContext and CombatContext.arena:
        CombatContext.arena.statuses.process_status_change(req)
    if req.canceled:
        probe.queue_free()
        return null

    if existing:
        probe.queue_free()
        var delta: int = stacks
        match existing.stack_mode:
            StatusEffect.StackMode.DURATION, StatusEffect.StackMode.INTENSITY:
                existing.stacks += delta
            StatusEffect.StackMode.REFRESH:
                existing.stacks = max(existing.stacks, delta)
            StatusEffect.StackMode.UNIQUE:
                pass
        existing.on_stacks_changed(delta)
        EventBus.status_stacks_changed.emit(_host(), existing, delta)
        return existing

    probe.stacks = stacks
    probe.host = _host()
    add_child(probe)
    probe.on_apply()
    EventBus.log_entry.emit(_host_display_name() + " gets " + probe.display_name)
    EventBus.status_applied.emit(_host(), probe)
    return probe

func remove(status_id: StringName) -> void:
    var existing: StatusEffect = find(status_id)
    if existing == null:
        return

    var req := StatusChangeRequest.new()
    req.kind = StatusChangeRequest.Kind.REMOVE
    req.host = _host()
    req.status_id = status_id
    process_status_change(req)
    if CombatContext and CombatContext.arena:
        CombatContext.arena.statuses.process_status_change(req)
    if req.canceled:
        return

    existing.on_remove()
    EventBus.log_entry.emit(_host_display_name() + " loses " + existing.display_name)
    EventBus.status_removed.emit(_host(), existing)
    remove_child(existing)
    existing.queue_free()

func remove_stack(status_id: StringName, amount: int = 1) -> void:
    var existing: StatusEffect = find(status_id)
    if existing == null:
        return
    existing.stacks = max(0, existing.stacks - amount)
    existing.on_stacks_changed(-amount)
    EventBus.status_stacks_changed.emit(_host(), existing, -amount)
    if existing.stacks <= 0:
        remove(status_id)

func find(status_id: StringName) -> StatusEffect:
    for child in get_children():
        if child is StatusEffect and child.id == status_id:
            return child
    return null

func process_outgoing_damage(info: DamageInfo) -> void:
    for s in _sorted():
        s.modify_outgoing_damage(info)
        if info.canceled:
            return

func process_incoming_damage(info: DamageInfo) -> void:
    for s in _sorted():
        s.modify_incoming_damage(info)
        if info.canceled:
            return

func process_pre_cast(info: SpellCastInfo) -> void:
    for s in _sorted():
        s.modify_pre_cast(info)
        if info.canceled:
            return

func process_pre_cast_incoming(info: SpellCastInfo) -> void:
    for s in _sorted():
        s.modify_pre_cast_incoming(info)
        if info.canceled:
            return

func process_post_cast(info: SpellCastInfo) -> void:
    for s in _sorted():
        s.modify_post_cast(info)

func process_status_change(req: StatusChangeRequest) -> void:
    for s in _sorted():
        s.intercept_status_change(req)
        if req.canceled:
            return

func _on_turn_started(actor) -> void:
    if actor != _host():
        return
    for s in get_children().duplicate():
        if s is StatusEffect:
            s.on_turn_start()

func _on_turn_ended(actor) -> void:
    if actor != _host():
        return
    for s in get_children().duplicate():
        if s is StatusEffect:
            s.on_turn_end()

func _host() -> Node:
    if _cached_host == null:
        _cached_host = _resolve_host()
    return _cached_host

func _host_display_name() -> String:
    var h: Node = _host()
    if h is Combatant and (h as Combatant).display_name != "":
        return (h as Combatant).display_name
    return "Target"

func _sorted() -> Array[StatusEffect]:
    var arr: Array[StatusEffect] = []
    for child in get_children():
        if child is StatusEffect and is_instance_valid(child):
            arr.append(child)
    arr.sort_custom(func(a, b): return a.priority > b.priority)
    return arr
