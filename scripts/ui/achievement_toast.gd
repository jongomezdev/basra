class_name AchievementToast
extends Control
## Slides an "Achievement unlocked" card down from the top of the screen.
## Unlocks that arrive together are shown one after another.

signal shown

const BRASS := Color("f5d78c")
const SLIDE_TIME := 0.35
const HOLD_TIME := 2.4
const TOP_MARGIN := 18.0

var _queue: Array[Dictionary] = []
var _showing := false
var _panel: PanelContainer
var _name_label: Label
var _reward_label: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 45


func _ready() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("201812")
	style.border_color = BRASS
	style.set_border_width_all(3)
	style.border_width_bottom = 6
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	style.content_margin_left = 28
	style.content_margin_right = 28
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	_panel.add_child(rows)
	rows.add_child(_label("Achievement unlocked", 22, Color("bfad94")))
	_name_label = _label("", 33, BRASS)
	rows.add_child(_name_label)
	_reward_label = _label("", 22, Color("f7f0df"))
	rows.add_child(_reward_label)
	_panel.position.y = -400


## Queues a pop-up. reward is extra text such as a new card back, or "".
func announce(title: String, reward: String) -> void:
	_queue.append({"title": title, "reward": reward})
	if not _showing:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var next: Dictionary = _queue.pop_front()
	_name_label.text = next.title
	_reward_label.text = next.reward
	_reward_label.visible = not (next.reward as String).is_empty()
	_panel.reset_size()
	var panel_size := _panel.get_combined_minimum_size()
	var hidden_y := -panel_size.y - 20
	_panel.position = Vector2((size.x - panel_size.x) / 2, hidden_y)
	shown.emit()

	var tween := create_tween()
	tween.tween_property(_panel, "position:y", TOP_MARGIN, SLIDE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD_TIME)
	tween.tween_property(_panel, "position:y", hidden_y, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(_show_next)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
