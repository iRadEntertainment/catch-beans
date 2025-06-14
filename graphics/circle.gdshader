shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.0, 0.01) = 1.0; // Radius of the circle
uniform float feather : hint_range(0.0, 1.0, 0.01) = 0.05; // Feathering of the circles edge

uniform vec2 center = vec2(0.5, 0.5); // Center (Adjust to move the circle around)

float circle_mask(vec2 _uv, vec2 _center, float _radius, float _feather) {
    float dist = length(_uv - _center); // Distance from current pixel to the center
    return smoothstep(_radius * 0.5, _radius * 0.5 - _feather, dist); // Smooth transition
}

void fragment() {
    COLOR.a = circle_mask(UV, center, radius, feather); // Use mask for transparency
}