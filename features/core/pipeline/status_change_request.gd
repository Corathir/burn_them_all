extends RefCounted

class_name StatusChangeRequest

enum Kind { APPLY, REMOVE, MODIFY_STACKS }

var kind: Kind
var host: Combatant
var status_id: StringName
var status_scene: PackedScene
var stacks: int = 1
var negative: bool = false
var canceled: bool = false