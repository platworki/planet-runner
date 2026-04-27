shader_type canvas_item;

uniform float reveal_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    // Calculate distance from center (0.5)
    float dist = abs(UV.x - 0.5);
    // If the distance is greater than half our reveal amount, hide it
    if (dist > reveal_amount * 0.5) {
        discard;
    }
}