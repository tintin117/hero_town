shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec2 grid_size = vec2(10.0, 3.0);
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);
uniform vec4 highlight_color : source_color = vec4(0.3, 1.0, 0.3, 0.5);
uniform vec2 highlight_cell = vec2(-1.0, -1.0);
uniform float line_width = 0.04;

void fragment() {
	vec2 cell_uv = UV * grid_size;
	vec2 frac = fract(cell_uv);
	float edge = min(min(frac.x, 1.0 - frac.x), min(frac.y, 1.0 - frac.y));
	float line_mask = 1.0 - smoothstep(0.0, line_width, edge);

	vec2 cell_id = floor(cell_uv);
	float is_highlight = step(abs(cell_id.x - highlight_cell.x), 0.5) * step(abs(cell_id.y - highlight_cell.y), 0.5);

	vec3 color = mix(line_color.rgb * line_mask, highlight_color.rgb, is_highlight);
	float alpha = max(line_color.a * line_mask, is_highlight * highlight_color.a);

	ALBEDO = color;
	ALPHA = alpha;
}
