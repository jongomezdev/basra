shader_type canvas_item;
// Slowly marbling felt. The domain warp folds sine waves into each other, and
// sampling on a coarse grid gives the chunky, low-resolution look.

uniform vec3 dark_color : source_color = vec3(0.075, 0.2, 0.165);
uniform vec3 mid_color : source_color = vec3(0.11, 0.285, 0.23);
uniform vec3 light_color : source_color = vec3(0.16, 0.37, 0.3);
uniform float pixel_size = 3.0;
uniform float speed = 0.06;

void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / pixel_size) * pixel_size;
	vec2 p = cell * 0.0042;
	float t = TIME * speed;
	for (int i = 1; i < 6; i++) {
		float f = float(i);
		p += vec2(
			sin(p.y * 1.4 + t * (1.0 + f * 0.3) + f * 1.7),
			cos(p.x * 1.2 - t * (0.8 + f * 0.25) + f * 2.3)
		) * (0.7 / f);
	}
	float v = 0.5 + 0.5 * sin(p.x * 1.6 + p.y * 1.1);
	vec3 color = mix(dark_color, mid_color, smoothstep(0.1, 0.55, v));
	color = mix(color, light_color, smoothstep(0.7, 0.95, v));
	COLOR = vec4(color, 1.0);
}
