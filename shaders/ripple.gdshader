shader_type canvas_item;

global uniform vec2 ripple_center_0;
global uniform float ripple_radius_0;
global uniform vec2 ripple_center_1;
global uniform float ripple_radius_1;
global uniform vec2 ripple_center_2;
global uniform float ripple_radius_2;
global uniform vec2 ripple_center_3;
global uniform float ripple_radius_3;
global uniform vec2 ripple_center_4;
global uniform float ripple_radius_4;
global uniform vec2 ripple_center_5;
global uniform float ripple_radius_5;
global uniform float ripple_alpha_0;
global uniform float ripple_alpha_1;
global uniform float ripple_alpha_2;
global uniform float ripple_alpha_3;
global uniform float ripple_alpha_4;
global uniform float ripple_alpha_5;
 
uniform float ripple_width : hint_range(1.0, 500.0) = 130.0;
uniform float fill_feather : hint_range(0.5, 50.0) = 5; // sharp edge for the purple fill itself
uniform float edge_softness : hint_range(1.0, 200.0) = 20; // pink glow width only
uniform vec4 ripple_color : source_color = vec4(0.05490, 0.00392, 0.12941, 1.0);
uniform vec4 edge_color : source_color = vec4(0.9, 0.3, 0.8, 1.0);
uniform vec4 star_color : source_color = vec4(0.729, 0.980, 0.6, 1.0);
uniform float edge_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float star_scale : hint_range(0.01, 1.0) = 0.75; // lower = bigger stars, higher = smaller
uniform float star_density : hint_range(0.9, 0.999) = 0.998; // lower = more stars
uniform bool debug_show_stars_everywhere = false; // TEMP: set true to test stars without ripple mask
 
varying vec2 world_pos;
 
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
 
float hash(vec2 p) {
	// Wrap into a repeating tile so large world coordinates don't
	// break sin() precision far from the origin.
	p = mod(p, 1000.0);
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
 
// Solid fill band, softened only at the two edges
float ripple_fill(vec2 pos, vec2 center, float radius, float alpha) {
	if (radius < 0.0) {
		return 0.0;
	}
	float dist = distance(pos, center);
	float band = smoothstep(radius - ripple_width - fill_feather, radius - ripple_width, dist)
	           - smoothstep(radius, radius + fill_feather, dist);
	return band * alpha;
}
 
float ripple_edge(vec2 pos, vec2 center, float radius, float alpha) {
	if (radius < 0.0) {
		return 0.0;
	}
	float dist = distance(pos, center);
	float outer_dist = abs(dist - radius);
	float inner_dist = abs(dist - (radius - ripple_width));
	float d = min(outer_dist, inner_dist);
	float edge = 1.0 - smoothstep(0.0, edge_softness, d);
	edge = edge * edge;
	return edge * alpha;
}
 
void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
 
	float total_fill = 0.0;
	float total_edge = 0.0;
 
	total_fill = max(total_fill, ripple_fill(world_pos, ripple_center_0, ripple_radius_0, ripple_alpha_0));
	total_fill = max(total_fill, ripple_fill(world_pos, ripple_center_1, ripple_radius_1, ripple_alpha_1));
	total_fill = max(total_fill, ripple_fill(world_pos, ripple_center_2, ripple_radius_2, ripple_alpha_2));
	total_fill = max(total_fill, ripple_fill(world_pos, ripple_center_3, ripple_radius_3, ripple_alpha_3));
	total_fill = max(total_fill, ripple_fill(world_pos, ripple_center_4, ripple_radius_4, ripple_alpha_4));
	total_fill = max(total_fill, ripple_fill(world_pos, ripple_center_5, ripple_radius_5, ripple_alpha_5));
 
	total_edge = max(total_edge, ripple_edge(world_pos, ripple_center_0, ripple_radius_0, ripple_alpha_0));
	total_edge = max(total_edge, ripple_edge(world_pos, ripple_center_1, ripple_radius_1, ripple_alpha_1));
	total_edge = max(total_edge, ripple_edge(world_pos, ripple_center_2, ripple_radius_2, ripple_alpha_2));
	total_edge = max(total_edge, ripple_edge(world_pos, ripple_center_3, ripple_radius_3, ripple_alpha_3));
	total_edge = max(total_edge, ripple_edge(world_pos, ripple_center_4, ripple_radius_4, ripple_alpha_4));
	total_edge = max(total_edge, ripple_edge(world_pos, ripple_center_5, ripple_radius_5, ripple_alpha_5));
 
	float n = hash(floor(world_pos * star_scale) + floor(TIME * 2.0));
	float stars = step(star_density, n);
 
	float star_mask = debug_show_stars_everywhere ? 1.0 : total_fill;
 
	vec3 result = mix(tex_color.rgb, ripple_color.rgb, total_fill * 0.9);
	result += star_color.rgb * stars * star_mask;
	result += edge_color.rgb * total_edge * edge_intensity;
 
	COLOR = vec4(result, tex_color.a);
}