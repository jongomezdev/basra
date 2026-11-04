class_name CardView
extends Control
## Draws one card with vector shapes, so the game ships no card art.
## With no card assigned it can only show its back (deck and capture piles).

signal pressed(view: CardView)
signal hover_changed(view: CardView, hovering: bool)

const CARD_SIZE := Vector2(100, 140)
const CORNER := 9
const TILT_SHADER := preload("res://shaders/card_tilt.gdshader")
const FONT := preload("res://assets/fonts/pixel_font.tres")

## The font's pixels only land on the screen grid at multiples of 11.
const RANK_FONT_SIZE := 22

const HOVER_SCALE := 1.1
const HOVER_TILT := 0.0013
const IDLE_TILT := 0.00035
const TILT_RESPONSE := 12.0

const FACE_COLOR := Color("f7f0df")
const FACE_EDGE := Color("3a2a20")
const INK_BLACK := Color("23201c")
const INK_RED := Color("b3262e")
const BACK_COLOR := Color("8e2a2e")
const BACK_EDGE := Color("3a2a20")
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

var card: Card
## Sways gently when true. Deck and pile stand-ins stay still.
var idle := true
## This card's resting angle on the table, so the layout looks hand-placed.
var table_angle := 0.0
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
var hovered := false:
	set(value):
		if hovered == value:
			return
		hovered = value
		z_index = 8 if value else 0
		_tween_scale(HOVER_SCALE if value else 1.0, 0.14)
		queue_redraw()

var _tilt := Vector2.ZERO
var _time := randf() * TAU
var _scale_tween: Tween


func _init() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	table_angle = randf_range(-3.0, 3.0)
	var tilt_material := ShaderMaterial.new()
	tilt_material.shader = TILT_SHADER
	tilt_material.set_shader_parameter("half_size", CARD_SIZE / 2)
	material = tilt_material


func _ready() -> void:
	mouse_entered.connect(func() -> void: hover_changed.emit(self, true))
	mouse_exited.connect(func() -> void: hover_changed.emit(self, false))


func _process(delta: float) -> void:
	_time += delta
	var target := Vector2.ZERO
	if idle:
		target = Vector2(sin(_time * 1.3), cos(_time * 0.9)) * IDLE_TILT
	if hovered:
		var from_center := (get_local_mouse_position() - CARD_SIZE / 2) / (CARD_SIZE / 2)
		target = from_center.clamp(-Vector2.ONE, Vector2.ONE) * HOVER_TILT
	_tilt = _tilt.lerp(target, 1.0 - exp(-delta * TILT_RESPONSE))
	(material as ShaderMaterial).set_shader_parameter("tilt", _tilt)


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


## Quick bounce for a card landing or scoring.
func pop(peak: float = 1.16) -> void:
	scale = Vector2.ONE * peak
	_tween_scale(1.0, 0.22)


func _tween_scale(target: float, duration: float) -> void:
	if _scale_tween:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, CARD_SIZE)
	var shadow_offset := Vector2(6, 9) if hovered else Vector2(4, 6)
	_draw_panel(Rect2(rect.position + shadow_offset, rect.size), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0), 0)
	if face_up and card != null:
		_draw_panel(rect, FACE_COLOR, FACE_EDGE, 2)
		_draw_face()
	else:
		_draw_panel(rect, BACK_COLOR, BACK_EDGE, 2)
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
		var area := Rect2(Vector2(38, 24), Vector2(24, 92))
		for pip: Vector2 in PIPS[card.rank]:
			_draw_suit(area.position + area.size * pip, 16.0, ink)
	else:
		var frame := Rect2(Vector2(25, 25), CARD_SIZE - Vector2(50, 50))
		draw_rect(frame, ink.lerp(FACE_COLOR, 0.65), false, 1.5, true)
		_draw_centered_text(card.rank_text(), center + Vector2(0, 2), RANK_FONT_SIZE * 2, ink)
		_draw_suit(center + Vector2(0, 30), 14.0, ink)


func _draw_corner(ink: Color) -> void:
	var text := card.rank_text()
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, RANK_FONT_SIZE).x
	var left := roundf(maxf(15 - width / 2, 5))
	draw_string(FONT, Vector2(left, 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, RANK_FONT_SIZE, ink)
	_draw_suit(Vector2(15, 35), 12.0, ink)


func _draw_centered_text(text: String, center: Vector2, font_size: int, ink: Color) -> void:
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center.y + FONT.get_ascent(font_size) - text_size.y / 2
	draw_string(FONT, Vector2(center.x - text_size.x / 2, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## A tile of eight-pointed stars, the mosaic motif of the card backs.
func _draw_back() -> void:
	var inset := Rect2(Vector2(8, 8), CARD_SIZE - Vector2(16, 16))
	draw_rect(inset, BRASS, false, 2.0)
	var step := 21.0
	var columns := int(inset.size.x / step)
	var rows := int(inset.size.y / step)
	var margin := (inset.size - Vector2(columns - 1, rows - 1) * step) / 2
	for row in rows:
		for column in columns:
			var center := inset.position + margin + Vector2(column, row) * step
			draw_colored_polygon(_square(center, 7.0, 0.0), BRASS)
			draw_colored_polygon(_square(center, 7.0, PI / 4), BRASS)
			draw_colored_polygon(_square(center, 3.0, PI / 4), BACK_COLOR)


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


func _square(center: Vector2, radius: float, angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 4:
		points.append(center + Vector2(radius, radius).rotated(angle + i * PI / 2))
	return points


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
