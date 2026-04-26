shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(0.525, 0.780, 0.922, 1.0);
uniform float thickness : hint_range(0.0, 10.0) = 1;
uniform bool add_margins = true;

void fragment() {
    vec2 size = TEXTURE_PIXEL_SIZE * thickness;
    vec4 sprite_color = texture(TEXTURE, UV);

    // Only calculate outline if we are within the sprite bounds
    float alpha = sprite_color.a;

    // We check if the neighbor exists before adding its alpha
    alpha += texture(TEXTURE, clamp(UV + vec2(0.0, size.y), vec2(0.0), vec2(1.0))).a;
    alpha += texture(TEXTURE, clamp(UV + vec2(0.0, -size.y), vec2(0.0), vec2(1.0))).a;
    alpha += texture(TEXTURE, clamp(UV + vec2(size.x, 0.0), vec2(0.0), vec2(1.0))).a;
    alpha += texture(TEXTURE, clamp(UV + vec2(-size.x, 0.0), vec2(0.0), vec2(1.0))).a;

    float outline_alpha = min(1.0, alpha);

    vec4 final_color = mix(sprite_color, outline_color, outline_alpha - sprite_color.a);
    COLOR = vec4(final_color.rgb, outline_alpha);
}
