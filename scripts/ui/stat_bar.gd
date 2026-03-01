extends Control

class_name StatBar

var max_value: int
var min_value: int
var current_value: int

@onready var bar: ProgressBar = $ProgressBar
@onready var label: Label = $Label

func init(max_value):
    self.min_value = 0
    self.max_value = max_value
    self.current_value = max_value

    bar.min_value = 0
    bar.max_value = max_value
    bar.value = max_value

    label.text = str(max_value)

func update_value(current_val):
    self.current_value = current_val
    bar.value = current_val
    label.text = str(current_val)
