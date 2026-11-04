class_name CardView
extends Control
## Draws one card with vector shapes, so the game ships no card art.
## With no card assigned it can only show its back (deck and capture piles).

signal pressed(view: CardView)
signal hover_changed(view: CardView, hovering: bool)

const CARD_SIZE := Vector2(100, 140)
const CORNER := 9

const FACE_COLOR := Color("f7f0df")
const FACE_EDGE := Color("c9bb9b")
const INK_BLACK := Color("23201c")
const INK_RED := Color("b3262e")
const BACK_COLOR := Color("74202b")
const BACK_EDGE := Color("4f141c")
const BRASS := Color("e0bb72")

## Pip positions as fractions of the pip area, for ranks 2-10.
const PIPS := {
	2: [Vector2(0.5, 0), Vector2(0.5, 1)],
	3: [Vector2(0.5, 0), Vector2(0.5, 0.5), Vector2(0.5, 1)],
	4: [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)],
	5: [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.5), Vector2(0, 1), Vector2(1, 1)],
	6: [Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0, 1), Vector2(1, 1)],
	7: [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.25), Vector2(0, 0.5), Vector2(1, 0.5),
		Vector2(0, 1), Vector2(1, 1)],
	8: [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.25), Vector2(0, 0.5), Vector2(1, 0.5),
		Vector2(0.5, 0.75), Vector2(0, 1), Vector2(1, 1)],
	9: [Vector2(0, 0), Vector2(1, 0), Vector2(0, 0.33), Vector2(1, 0.33), Vector2(0.5, 0.5),
		Vector2(0, 0.67), Vector2(1, 0.67), Vector2(0, 1), Vector2(1, 1)],
	10: [Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 0.17), Vector2(0, 0.33), Vector2(1, 0.33),
		Vector2(0, 0.67), Vector2(1, 0.67), Vector2(0.5, 0.83), Vector2(0, 1), Vector2(1, 1)],
}

static var _font: SystemFont

var card: Card
var face_up := false:
	set(value):
		face_up = value
		queue_redraw()
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()
var playable := false:
	set(value):
		playable = value
		mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Georgia", "Times New Roman", "serif"])
		_font.font_weight = 700


func _ready() -> void:
	mouse_entered.connect(func() -> void: hover_changed.emit(self, true))
	mouse_exited.connect(func() -> void: hover_changed.emit(self, false))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and button.pressed:
		accept_event()
		pressed.emit(self)


## Turns the card over with a quick squash, returning the tween to await.
func flip_to(show_face: bool, duration: float = 0.18) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "scale:x", 0.0, duration / 2)
	tween.tween_callback(func() -> void: face_up = show_face)
	tween.tween_property(self, "scale:x", 1.0, duration / 2)
	return tween


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, CARD_SIZE)
	_draw_panel(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, 0.32), Color(0, 0, 0, 0), 0)
	if face_up and card != null:
		_draw_panel(rect, FACE_COLOR, FACE_EDGE, 1)
		_draw_face()
	else:
		_draw_panel(rect, BACK_COLOR, BACK_EDGE, 1)
		_draw_back()
	if highlighted:
		_draw_panel(rect.grow(2), Color(0, 0, 0, 0), BRASS, 4)


func _draw_panel(rect: Rect2, fill: Color, edge: Color, border: int) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(CORNER)
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _draw_face() -> void:
	var ink := INK_RED if card.is_red() else INK_BLACK
	_draw_corner(ink)
	draw_set_transform(CARD_SIZE, PI, Vector2.ONE)
	_draw_corner(ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var center := CARD_SIZE / 2
	if card.rank == Card.ACE:
		_draw_suit(center, 46.0, ink)
	elif card.is_number():
		var area := Rect2(Vector2(33, 24), Vector2(34, 92))
		for pip: Vector2 in PIPS[card.rank]:
			_draw_suit(area.position + area.size * pip, 17.0, ink)
	else:
		var frame := Rect2(Vector2(25, 25), CARD_SIZE - Vector2(50, 50))
		draw_rect(frame, ink.lerp(FACE_COLOR, 0.65), false, 1.5, true)
		_draw_centered_text(card.rank_text(), center + Vector2(0, 2), 46, ink)
		_draw_suit(center + Vector2(0, 30), 14.0, ink)


func _draw_corner(ink: Color) -> void:
	var text := card.rank_text()
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	draw_string(_font, Vector2(14 - width / 2, 23), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, ink)
	_draw_suit(Vector2(14, 33), 11.0, ink)


func _draw_centered_text(text: String, center: Vector2, font_size: int, ink: Color) -> void:
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center.y + _font.get_ascent(font_size) - text_size.y / 2
	draw_string(_font, Vector2(center.x - text_size.x / 2, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


func _draw_back() -> void:
	var inset := Rect2(Vector2(8, 8), CARD_SIZE - Vector2(16, 16))
	draw_rect(inset, BRASS, false, 1.5, true)
	var step := Vector2(14, 14)
	var columns := int(inset.size.x / step.x)
	var rows := int(inset.size.y / step.y)
	var margin := (inset.size - Vector2(columns - 1, rows - 1) * step) / 2
	for row in rows:
		for column in columns:
			var center := inset.position + margin + Vector2(column, row) * step
			var radius := 4.5 if (row + column) % 2 == 0 else 2.0
			draw_colored_polygon(_diamond(center, radius), BRASS.darkened(0.12))


func _draw_suit(center: Vector2, height: float, ink: Color) -> void:
	match card.suit:
		Card.Suit.DIAMONDS:
			var half := height / 2
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -half), center + Vector2(half * 0.76, 0),
				center + Vector2(0, half), center + Vector2(-half * 0.76, 0),
			]), ink)
		Card.Suit.HEARTS:
			draw_colored_polygon(_heart(center, height, false), ink)
		Card.Suit.SPADES:
			draw_colored_polygon(_heart(center + Vector2(0, -height * 0.06), height * 0.88, true), ink)
			_draw_stem(center, height, ink)
		Card.Suit.CLUBS:
			var radius := height * 0.235
			draw_circle(center + Vector2(0, -height * 0.25), radius, ink)
			draw_circle(center + Vector2(-height * 0.25, height * 0.08), radius, ink)
			draw_circle(center + Vector2(height * 0.25, height * 0.08), radius, ink)
			draw_circle(center + Vector2(0, -height * 0.02), radius * 0.6, ink)
			_draw_stem(center, height, ink)


func _draw_stem(center: Vector2, height: float, ink: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, height * 0.02),
		center + Vector2(height * 0.17, height * 0.5),
		center + Vector2(-height * 0.17, height * 0.5),
	]), ink)


func _diamond(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0),
	])


func _heart(center: Vector2, height: float, inverted: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var scale_factor := height / 30.0
	var flip := -1.0 if inverted else 1.0
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		points.append(center + Vector2(x, -(y + 2.5) * flip) * scale_factor)
	return points
