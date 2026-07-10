shader_type canvas_item;

// Stylized full-screen transition wipe for the title intro. Pure overlay (no
// screen read): it only emits a colored frontier with alpha. Contract used by the
// scene: alpha is 0 at progress 0, ~1 (fully covered) at progress 0.5, and 0
// again at progress 1. The first half sweeps the effect in to black, the second
// half sweeps it back out, so the scene can swap shots at the covered midpoint.
//
// wipe_type: 0 soft_fade, 1 light_sweep, 2 ink_splash, 3 smoke_fog,
//            4 shadow_wipe, 5 whip, 6 zoom_through, 7 particle_dissolve,
//            8 blur (radial zoom-blur converging to black; pure overlay).

uniform int wipe_type : hint_range(0, 8) = 0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float angle : hint_range(-3.1416, 3.1416) = 0.0;
uniform vec4 wipe_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float soft : hint_range(0.01, 0.4) = 0.12;
uniform float seed : hint_range(0.0, 100.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 13.37) * 43758.5453123);
}

// 0->1->0 envelope: fully covered at progress 0.5.
float envelope() {
	return 1.0 - abs(progress * 2.0 - 1.0); // 0 at 0, 1 at 0.5, 0 at 1
}

// Directional coordinate 0..1 across the screen along `angle`.
float dir_coord(vec2 uv) {
	vec2 d = normalize(vec2(cos(angle), sin(angle)));
	return dot(uv - 0.5, d) + 0.5;
}

// Covered region grows as frontier f (0..1) rises; shrinks as it falls.
float frontier(float u, float f, float s) {
	return 1.0 - smoothstep(f - s, f + s, u);
}

void fragment() {
	vec2 uv = UV;
	float env = envelope();           // 0..1..0 across the whole transition
	float f = clamp(progress * 2.0, 0.0, 1.0); // 0->1 over the cover half
	if (progress > 0.5) {
		f = clamp((1.0 - progress) * 2.0, 0.0, 1.0); // 1->0 over the reveal half
	}

	float cov = 0.0;

	if (wipe_type == 0) {
		// Soft uniform fade.
		cov = env;
	} else if (wipe_type == 6) {
		// Zoom-through: radial bloom from centre.
		float d = length((uv - 0.5) * vec2(1.777, 1.0)) * 1.6;
		cov = frontier(d, f, soft);
	} else if (wipe_type == 8) {
		// Blur: a streaky radial frontier that closes to full black at the
		// midpoint (GPU-safe overlay, no screen read). Angular streaks make it
		// read as a zoom/motion blur rather than a flat fade. The f*1.25 bias
		// guarantees the far corners are fully covered at progress 0.5.
		vec2 c = uv - 0.5;
		float r = length(c * vec2(1.777, 1.0));
		float ang = atan(c.y, c.x);
		float streak = 0.5 + 0.5 * sin(ang * 30.0 + r * 60.0 - seed * 0.7);
		float u = r - (streak - 0.5) * 0.10;
		cov = frontier(u, f * 1.25, soft * 1.2);
	} else {
		// Directional family (light/ink/smoke/shadow/whip/particle).
		float u = dir_coord(uv);
		float s = soft;
		if (wipe_type == 2) {
			// Ink splash: ragged, heavy frontier.
			u += (hash(uv * 6.0) - 0.5) * 0.28;
			s = soft * 1.6;
		} else if (wipe_type == 3) {
			// Smoke/fog: broad, soft, billowy.
			u += (hash(uv * 3.0) - 0.5) * 0.22;
			s = soft * 2.4;
		} else if (wipe_type == 1) {
			// Light sweep: tight bright band.
			s = soft * 0.6;
		} else if (wipe_type == 5) {
			// Whip: horizontal motion-blur streaks.
			u += (hash(vec2(0.0, floor(uv.y * 40.0))) - 0.5) * 0.18;
			s = soft * 0.5;
		} else if (wipe_type == 7) {
			// Particle dissolve: grainy break-up.
			u += (hash(uv * 14.0) - 0.5) * 0.35;
			s = soft * 0.9;
		}
		cov = frontier(u, f, s);
	}

	// Light sweep flashes bright rather than black; everything else uses wipe_color
	// (near-black). Keep alpha 0->1->0 regardless.
	float a = clamp(cov, 0.0, 1.0) * wipe_color.a;
	COLOR = vec4(wipe_color.rgb, a);
}
