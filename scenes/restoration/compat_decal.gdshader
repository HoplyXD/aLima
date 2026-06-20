shader_type spatial;
render_mode world_vertex_coords, blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;
// A box-projected "forward decal" that works in the Compatibility (gl_compatibility)
// renderer, where the engine's Decal node does not draw. Apply this material to a
// cube MeshInstance3D (BoxMesh side = 2 * cube_half_size) positioned straddling the
// target surface; orient the box so its local +Y axis points along the surface
// normal — the albedo's XZ plane is then stamped down the box onto the geometry
// inside it. Adapted from the godotshaders.com compatibility decal shader.

uniform sampler2D albedo : source_color, repeat_disable;
uniform vec4 modulate : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float albedo_mix : hint_range(0.0, 1.0, 0.05) = 1.0;
uniform float cube_half_size = 0.5;  // Must match BoxMesh half-extent.
uniform vec2 uv_scale = vec2(1.0, 1.0);

uniform sampler2D depth_tex : hint_depth_texture;

// Optional fade along the projection (Y) axis, e.g. to soften the decal's edges.
uniform bool enable_y_fade = false;
uniform float fade_start = 0.3;
uniform float fade_end = 0.7;
uniform float fade_power = 2.0;

varying mat4 inv_model;

void vertex() {
	inv_model = inverse(MODEL_MATRIX);
}

float smooth_fade(float y_pos) {
	float normalized_y = clamp((y_pos + cube_half_size) / (2.0 * cube_half_size), 0.0, 1.0);
	float fade_factor = smoothstep(fade_start, fade_end, normalized_y);
	fade_factor = pow(fade_factor, fade_power);
	return 1.0 - fade_factor;
}

void fragment() {
	// Reconstruct the world position of the surface behind this fragment from depth.
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 clip = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * clip;
	view /= view.w;
	vec3 world = (INV_VIEW_MATRIX * view).xyz;
	vec4 local = inv_model * vec4(world, 1.0);

	// Outside the projection box → no decal here.
	if (abs(local.x) > cube_half_size || abs(local.y) > cube_half_size || abs(local.z) > cube_half_size) {
		discard;
	}

	vec2 decal_uv = (local.xz / (2.0 * cube_half_size)) + 0.5;
	vec4 tex = texture(albedo, decal_uv * uv_scale);

	float y_fade = 1.0;
	if (enable_y_fade) {
		y_fade = smooth_fade(local.y);
		if (y_fade <= 0.0) {
			discard;
		}
	}

	ALBEDO = tex.rgb * modulate.rgb;
	ALPHA = tex.a * albedo_mix * modulate.a * y_fade;
}
