class_name RotatePrompt
extends Control
## Covers the game with a "turn your phone sideways" message whenever the
## screen is taller than it is wide, and pauses play until it isn't.

const BRASS := Color("f5d78c")
const TURN_TIME := 0.9
const HOLD_TIME := 0.7

var _paused_by_us := false
var _icon: Control


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	visible = false


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("13332a")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 60)
	center.add_child(rows)

	_icon = PhoneIcon.new()
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rows.add_child(_icon)
	rows.add_child(_label("Turn your phone sideways", 88, BRASS))
	rows.add_child(_label("Basra plays in landscape.", 55, Color("f7f0df")))

	var tween := create_tween().set_loops()
	tween.tween_property(_icon, "rotation_degrees", -90.0, TURN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_icon, "rotation_degrees", 0.0, 0.0)
	tween.tween_interval(HOLD_TIME * 0.5)


func _process(_delta: float) -> void:
	var screen := get_viewport().get_visible_rect().size
	var portrait := screen.y > screen.x
	if portrait == visible:
		return
	visible = portrait
	if portrait:
		# Only pause if nothing else (like the pause menu) already has.
		_paused_by_us = not get_tree().paused
		get_tree().paused = true
	elif _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## A phone outline that the prompt turns on its side.
class PhoneIcon:
	extends Control

	const PHONE_SIZE := Vector2(170, 300)

	func _init() -> void:
		custom_minimum_size = Vector2(PHONE_SIZE.y, PHONE_SIZE.y)
		pivot_offset = custom_minimum_size / 2

	func _draw() -> void:
		var body := StyleBoxFlat.new()
		body.bg_color = Color(0, 0, 0, 0)
		body.border_color = Color("f5d78c")
		body.set_border_width_all(14)
		body.set_corner_radius_all(28)
		var rect := Rect2((size - PHONE_SIZE) / 2, PHONE_SIZE)
		draw_style_box(body, rect)
		draw_rect(Rect2(rect.position + Vector2(PHONE_SIZE.x / 2 - 30, 22), Vector2(60, 10)), Color("f5d78c"))
