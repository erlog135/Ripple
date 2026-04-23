shader_type canvas_item;

// Adjust this to make the pixels larger or smaller
uniform float pixel_size : hint_range(1.0, 16.0, 1.0) = 4.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

void fragment() {
    // Snap the UV coordinates to a grid
    vec2 grid_uv = round(SCREEN_UV * (1.0 / SCREEN_PIXEL_SIZE) / pixel_size) * pixel_size * SCREEN_PIXEL_SIZE;
    COLOR = texture(screen_texture, grid_uv);
}