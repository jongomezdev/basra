shader_type canvas_item;
// Fakes a card tilting in 3D: the side with a larger w recedes from the viewer.

uniform vec2 tilt = vec2(0.0);
uniform vec2 half_size = vec2(50.0, 70.0);

void vertex() {
	vec2 from_center = VERTEX - half_size;
	float w = 1.0 + dot(from_center, tilt);
	VERTEX = half_size + from_center / max(w, 0.2);
}
