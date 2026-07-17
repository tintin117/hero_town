shader_type spatial;
render_mode blend_mix, cull_disabled, diffuse_lambert, specular_disabled;

// Assign the SAME texture you have set on the Sprite3D node itself here too.
uniform sampler2D texture_albedo : source_color;

// === Bevel / fake thickness ===
uniform float bevel_width : hint_range(0.5, 12.0) = 4.0;   // pixels
uniform float bevel_strength : hint_range(0.0, 3.0) = 1.2;

// === Fake AO near the silhouette edge ===
uniform float ao_strength : hint_range(0.0, 1.0) = 0.4;

// === Rim light — reads as the bevel edge catching light ===
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 3.0) = 1.0;
uniform float rim_power : hint_range(0.5, 8.0) = 3.0;

// === Cutout ===
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.3;

// Matte paper: no specular highlight
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;

// 5-tap box sample of alpha — cheap stand-in for a distance/height field near the edge
float sample_alpha(vec2 uv, vec2 texel, float radius_px) {
	float a = texture(texture_albedo, uv).a;
	a += texture(texture_albedo, uv + texel * vec2( radius_px, 0.0)).a;
	a += texture(texture_albedo, uv + texel * vec2(-radius_px, 0.0)).a;
	a += texture(texture_albedo, uv + texel * vec2(0.0,  radius_px)).a;
	a += texture(texture_albedo, uv + texel * vec2(0.0, -radius_px)).a;
	return a / 5.0;
}

void fragment() {
	vec2 tex_size = vec2(textureSize(texture_albedo, 0));
	vec2 texel = 1.0 / tex_size;

	vec4 tex = texture(texture_albedo, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;

	// Build a soft height field from alpha, then take its gradient -> fake bevel normal
	float radius = bevel_width * 0.33;
	float h0  = sample_alpha(UV, texel, radius);
	float hxp = sample_alpha(UV + texel * vec2(bevel_width, 0.0), texel, radius);
	float hxn = sample_alpha(UV - texel * vec2(bevel_width, 0.0), texel, radius);
	float hyp = sample_alpha(UV + texel * vec2(0.0, bevel_width), texel, radius);
	float hyn = sample_alpha(UV - texel * vec2(0.0, bevel_width), texel, radius);

	float dx = (hxp - hxn) * bevel_strength;
	float dy = (hyp - hyn) * bevel_strength;

	// bevel_normal is in the CARD's own tangent space: x/y across the quad, z out of the card face
	vec3 bevel_normal = normalize(vec3(-dx, -dy, 0.6));

	// Apply it like a normal map on top of the billboard's existing flat normal/tangent basis,
	// so it tilts with whatever direction Sprite3D's billboard mode is currently facing.
	NORMAL = normalize(
		TANGENT * bevel_normal.x +
		BINORMAL * bevel_normal.y +
		NORMAL * bevel_normal.z
	);

	// Fake AO: darker near the silhouette edge, like a paper crease
	float ao = smoothstep(0.0, 1.0, h0);
	ALBEDO *= mix(1.0 - ao_strength, 1.0, ao);

	// View-dependent rim light — sells the bevel thickness regardless of which way real lights point
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * fresnel * rim_strength;
}
