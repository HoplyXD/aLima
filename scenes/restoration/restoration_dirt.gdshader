shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

// Lightweight surface dirt mask for the focused 3D restoration view (REST-R8, D8).
//
// The dirt amount is stored in a small R8/RGBA8 mask texture that the gameplay
// code paints into as the player works the tool across the surface (1.0 = dirty,
// 0.0 = clean). Both this shader and the GDScript that paints the mask derive the
// UV analytically from the object-space normal (spherical mapping), so painted
// regions always line up with the rendered grime regardless of the mesh's own UV
// layout. Kept deliberately simple so it compiles under GL Compatibility and the
// HTML5 export target.

uniform sampler2D dirt_mask : filter_linear, repeat_disable;
uniform vec4 clean_color : source_color = vec4(0.83, 0.80, 0.55, 1.0);
uniform vec4 grime_color : source_color = vec4(0.18, 0.15, 0.09, 1.0);
uniform float base_metallic : hint_range(0.0, 1.0) = 0.55;
uniform float base_roughness : hint_range(0.0, 1.0) = 0.45;

// Optional runtime "paint layer" (DrawableTexture2D): grime/damage the player draws onto the
// surface, sampled at the SAME analytic sphere UV so a stamp lands exactly where the tool is
// worked. Inert by default — paint_enabled is 0 until gameplay assigns a paint texture and
// turns it on, so an unset (white) sampler can never wash the surface out.
uniform sampler2D paint_layer : source_color, filter_linear, repeat_disable;
uniform float paint_enabled : hint_range(0.0, 1.0) = 0.0;

varying vec3 v_local_normal;

vec2 sphere_uv(vec3 n) {
	// PI / TAU are built-in shader constants in the Godot shading language.
	float u = 0.5 + atan(n.x, n.z) / TAU;
	float v = 0.5 - asin(clamp(n.y, -1.0, 1.0)) / PI;
	return vec2(u, v);
}

void vertex() {
	v_local_normal = normalize(NORMAL);
}

void fragment() {
	vec2 uv = sphere_uv(normalize(v_local_normal));
	float dirt = texture(dirt_mask, uv).r;
	ALBEDO = mix(clean_color.rgb, grime_color.rgb, dirt);
	// Composite the drawn paint layer over the grime (gated by paint_enabled so it is a no-op
	// until gameplay supplies a real texture). Painted spots read as fresh grime: dull + rough.
	vec4 paint = texture(paint_layer, uv);
	float pa = paint.a * paint_enabled;
	ALBEDO = mix(ALBEDO, paint.rgb, pa);
	dirt = max(dirt, pa);
	// Grime reads as dull and non-metallic; cleaned silver reads bright and shiny.
	METALLIC = base_metallic * (1.0 - dirt * 0.8);
	ROUGHNESS = mix(base_roughness, 0.95, dirt);
}
