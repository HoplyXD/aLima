shader_type canvas_item;

// Full-screen cinematic overlay for the title intro.
// Pure overlay (no screen read): dark vignette at the edges + faint animated
// film grain everywhere. Layered above the montage; alpha-only so it never
// washes out the picture. Keeps the look: deep blacks, soft falloff, grain.

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_radius : hint_range(0.2, 1.3) = 0.78;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.62;
uniform float aspect : hint_range(0.5, 3.0) = 1.777; // 16:9
uniform float grain_amount : hint_range(0.0, 0.15) = 0.03;
uniform float grain_scale : hint_range(200.0, 1400.0) = 800.0;
uniform float grain_speed : hint_range(0.0, 120.0) = 30.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 c = UV - 0.5;
	c.x *= aspect; // keep the vignette circular on a wide screen
	float d = length(c);
	float vig = smoothstep(vignette_radius, vignette_radius - vignette_softness, d);
	float edge = (1.0 - vig) * vignette_strength; // 0 center -> strength at corners

	float g = hash(floor(UV * grain_scale) + fract(TIME * grain_speed));
	float grain_a = g * grain_amount;

	// Edge darkness wins over grain where both exist; centre keeps faint grain.
	float a = max(edge, grain_a);
	vec3 col = (edge >= grain_a) ? vec3(0.0) : vec3(g * 0.7);
	COLOR = vec4(col, clamp(a, 0.0, 0.92));
}
