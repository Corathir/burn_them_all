extends StatusEffect

class_name ShieldStatus

@onready var icon: TextureRect = $Icon
@onready var charges_label: Label = $ChargesLabel

func _init() -> void:
    id = &"shield"
    display_name = "Shield"
    stack_mode = StackMode.INTENSITY
    priority = 100

func on_apply() -> void:
    _update_visual()

func on_stacks_changed(_delta: int) -> void:
    _update_visual()

func intercept_status_change(req: StatusChangeRequest) -> void:
    if req.canceled or stacks <= 0:
        return
    if req.kind != StatusChangeRequest.Kind.APPLY:
        return
    if not req.negative:
        return
    if req.status_id == id:
        return
    req.canceled = true
    EventBus.log_entry.emit("Shield blocks " + String(req.status_id))
    (host as Combatant).statuses.remove_stack(id, 1)

func to_info_data() -> Dictionary:
    var data: Dictionary = super.to_info_data()
    if icon and icon.texture:
        data["icon"] = icon.texture
    data["description"] = "Cancels the next negative status applied to you and consumes one charge."
    return data

func _update_visual() -> void:
    if charges_label:
        charges_label.text = str(stacks)
        charges_label.visible = stacks > 1
