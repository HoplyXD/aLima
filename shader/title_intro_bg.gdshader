shader_type canvas_item;

// Procedural warm "anime junkshop interior" backdrop for the title intro. Pure
// math — no art, no screen read, GPU-safe. Sits behind the portraits as a soft,
// low-contrast mood plate: a walnut->bronze->parchment vertical glow, a warm
// light pool (lamp/window), faint shelf slats, and drifting dust + ember specks.
// `mood` is a per-beat tint the script cross-fades so the backdrop shifts hue
// between the lineup and the second montage without swapping the layer.

uniform vec3 mood : source_color = vec3(1.0, 0.96, 0.88);
uniform float intensity : hint_range(0.0, 1.2) = 0.9;
uniform float dust_amount : hint_range(0.0, 1.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;

	// Vertical warm gradient: deep walnut at the floor, bronze mid, soft
	// parchment glow up near the "horizon" where the light comes in.
	vec3 walnut = vec3(0.10, 0.06, 0.035);
	vec3 bronze = vec3(0.34, 0.20, 0.10);
	vec3 parchment = vec3(0.62, 0.46, 0.30);
	vec3 col = mix(bronze, walnut, smoothstep(0.35, 1.0, uv.y));
	col = mix(parchment, col, smoothstep(0.0, 0.55, uv.y));

	// Warm light pool near the upper-centre (a lamp or a high window).
	float pool = exp(-pow(length((uv - vec2(0.5, 0.26)) * vec2(1.6, 1.0)) * 3.0, 2.0));
	col += vec3(0.30, 0.20, 0.10) * pool;

	// Faint horizontal shelf slats (thin dark bands), very low alpha.
	float bands = step(0.93, fract(uv.y * 9.0)) * 0.07;
	col *= (1.0 - bands);

	// Drifting dust motes + a few ember specks, hash-animated, kept subtle.
	float t = TIME * 0.05;
	float dust = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 cell = floor((uv + vec2(t * (0.30 + fi * 0.10), -t * 0.20)) * (40.0 + fi * 20.0));
		float h = hash(cell + fi);
		dust += smoothstep(0.985, 1.0, h) * (0.10 - fi * 0.025);
	}
	col += vec3(1.0, 0.85, 0.60) * dust * dust_amount;

	// Per-beat mood tint + overall intensity.
	col *= mood;
	col *= intensity;

	COLOR = vec4(col, 1.0);
}
