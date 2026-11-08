class_name PixelGlyphs
extends RefCounted
## Hand-drawn 5x7 pixel letters for card ranks. Drawing them as rectangles
## keeps every rank crisp at any scale, where a font's small sizes blur.

const HEIGHT := 7

## Each glyph is a list of rows; "#" is a filled pixel. "1" is narrower and
## its empty right column doubles as the gap in "10".
const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
	"0": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
}


static func text_size(text: String, pixel: float) -> Vector2:
	var columns := 0
	for character in text:
		columns += (GLYPHS[character][0] as String).length()
	return Vector2(columns, HEIGHT) * pixel


static func draw_text(canvas: CanvasItem, text: String, top_left: Vector2, pixel: float, color: Color) -> void:
	var x := top_left.x
	for character in text:
		var rows: Array = GLYPHS[character]
		for row in rows.size():
			var line: String = rows[row]
			for column in line.length():
				if line[column] == "#":
					canvas.draw_rect(Rect2(Vector2(x + column * pixel, top_left.y + row * pixel), Vector2(pixel, pixel)), color)
		x += (rows[0] as String).length() * pixel
