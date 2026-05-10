extends Control

class_name IntentDisplay

@onready var icon: TextureRect = $HBox/Icon
@onready var amount_label: Label = $HBox/Amount

var intent: EnemyIntent

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    if intent == null:
        visible = false

func set_intent(new_intent: EnemyIntent) -> void:
    intent = new_intent
    if not is_node_ready():
        await ready
    if intent == null:
        visible = false
        return
    icon.texture = intent.icon
    amount_label.text = str(intent.amount) if intent.has_amount() else ""
    amount_label.visible = intent.has_amount()
    visible = true

func _on_mouse_entered() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel and intent:
        panel.show_for(self, intent.to_info_data())

func _on_mouse_exited() -> void:
    var panel: InfoPanel = CombatContext.info_panel
    if panel:
        panel.hide_panel()
