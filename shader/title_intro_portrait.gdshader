shader_type canvas_item;

// Cinematic monochrome portrait treatment for the title intro.
// Desaturates the source art, adds gentle contrast, then throws one side of
// the frame into deep shadow so a "rim/side/top light" can read across the face.
// `lit` is animated by the scene (0 -> 1) to reveal the character from darkness.

uniform float contrast : hint_range(0.5, 2.0) = 1.12;
uniform float brightness : hint_range(-0.3, 0.3) = -0.02;
// 0 = lit from right, 1 = lit from left, 2 = lit from top, 3 = lit from bottom.
uniform int light_dir : hint_range(0, 3) = 0;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.55;
uniform float shadow_softness : hint_range(0.05, 1.0) = 0.55;
uniform float lit : hint_range(0.0, 1.5) = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
// 0 = pure black-and-white (current look), 1 = fully tinted grey. Ramped across
// the montage to ease from B&W into muted medieval color.
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;
// Lit-side color (rim / candle / moon / top light). Only the lit side (high
// `shade`) is tinted, so the shadow side stays deep.
uniform vec4 light_color : source_color = vec4(1.0);
uniform float light_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);

	// Luminance -> gentle S-curve-ish contrast around mid grey.
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	l = clamp((l - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);

	// Directional shadow: `shade` is high on the lit side, low in shadow.
	float axis;
	if (light_dir == 0) { axis = UV.x; }          // right side lit
	else if (light_dir == 1) { axis = 1.0 - UV.x; } // left side lit
	else if (light_dir == 2) { axis = 1.0 - UV.y; } // top lit
	else { axis = UV.y; }                           // bottom lit
	float shade = smoothstep(0.5 - shadow_softness * 0.5, 0.5 + shadow_softness * 0.5, axis);
	float shade_mul = mix(1.0 - shadow_strength, 1.0, shade);

	l *= shade_mul * lit;

	vec3 grey = vec3(l);
	// B&W -> muted color ramp.
	vec3 col = mix(grey, grey * tint.rgb, tint_strength);
	// Lit-side rim/candle/moon tint, scaled by local luminance so it glazes the
	// lit planes without flattening the shadow side.
	float rim = clamp(shade * light_strength, 0.0, 1.0);
	col = mix(col, light_color.rgb * (l + 0.15), rim);

	COLOR = vec4(col, c.a * tint.a);
}
