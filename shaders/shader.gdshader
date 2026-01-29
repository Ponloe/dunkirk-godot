shader_type canvas_item;

// This lets you pick the color in the Inspector
uniform vec4 remove_color : source_color; 

void fragment() {
    vec4 curr_color = texture(TEXTURE, UV);
    
    // If the pixel color is very close to our target color...
    if (distance(curr_color.rgb, remove_color.rgb) < 0.01) {
        // ...make it invisible (Alpha = 0)
        curr_color.a = 0.0;
    }
    
    COLOR = curr_color;
}