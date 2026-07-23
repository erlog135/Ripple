shader_type canvas_item;

// Screen texture sampler for Godot 4
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

const int PALETTE_SIZE = 64;
const float TOLERANCE = 0.2;

// Converts a 24-bit hexadecimal integer (e.g., 0x0055FFAA) into a normalized RGB vec3
vec3 hex_to_rgb(uint hex) {
    float r = float((hex >> 16u) & 0xFFu) / 255.0;
    float g = float((hex >> 8u) & 0xFFu) / 255.0;
    float b = float(hex & 0xFFu) / 255.0;
    return vec3(r, g, b);
}

// Target base colors (data-hex) in ascending hexadecimal order
const uint target_hex[PALETTE_SIZE] = uint[](
    0x000000u, 0x000055u, 0x0000AAu, 0x0000FFu,
    0x005500u, 0x005555u, 0x0055AAu, 0x0055FFu,
    0x00AA00u, 0x00AA55u, 0x00AAAAu, 0x00AAFFu,
    0x00FF00u, 0x00FF55u, 0x00FFAAu, 0x00FFFFu,
    0x550000u, 0x550055u, 0x5500AAu, 0x5500FFu,
    0x555500u, 0x555555u, 0x5555AAu, 0x5555FFu,
    0x55AA00u, 0x55AA55u, 0x55AAAAu, 0x55AAFFu,
    0x55FF00u, 0x55FF55u, 0x55FFAAu, 0x55FFFFu,
    0xAA0000u, 0xAA0055u, 0xAA00AAu, 0xAA00FFu,
    0xAA5500u, 0xAA5555u, 0xAA55AAu, 0xAA55FFu,
    0xAAAA00u, 0xAAAA55u, 0xAAAAAAu, 0xAAAAFFu,
    0xAAFF00u, 0xAAFF55u, 0xAAFFAAu, 0xAAFFFFu,
    0xFF0000u, 0xFF0055u, 0xFF00AAu, 0xFF00FFu,
    0xFF5500u, 0xFF5555u, 0xFF55AAu, 0xFF55FFu,
    0xFFAA00u, 0xFFAA55u, 0xFFAAAAu, 0xFFAAFFu,
    0xFFFF00u, 0xFFFF55u, 0xFFFFAAu, 0xFFFFFFu
);

// Corresponding sunlight replacements (fill) mapped to the same index
const uint swap_hex[PALETTE_SIZE] = uint[](
    0x000000u, 0x001E41u, 0x004387u, 0x0068CAu,
    0x2B4A2Cu, 0x27514Fu, 0x16638Du, 0x007DCEu,
    0x5E9860u, 0x5C9B72u, 0x57A5A2u, 0x4CB4DBu,
    0x8EE391u, 0x8EE69Eu, 0x8AEBC0u, 0x84F5F1u,
    0x4A161Bu, 0x482748u, 0x40488Au, 0x2F6BCCu,
    0x564E36u, 0x545454u, 0x4F6790u, 0x4180D0u,
    0x759A64u, 0x759D76u, 0x71A6A4u, 0x69B5DDu,
    0x9EE594u, 0x9DE7A0u, 0x9BECC2u, 0x95F6F2u,
    0x99353Fu, 0x983E5Au, 0x955694u, 0x8F74D2u,
    0x9D5B4Du, 0x9D6064u, 0x9A7099u, 0x9587D5u,
    0xAFA072u, 0xAEA382u, 0xABABABu, 0xA7BAE2u,
    0xC9E89Du, 0xC9EAA7u, 0xC7F0C8u, 0xC3F9F7u,
    0xE35462u, 0xE25874u, 0xE16AA3u, 0xDE83DCu,
    0xE66E6Bu, 0xE6727Cu, 0xE37FA7u, 0xE194DFu,
    0xF1AA86u, 0xF1AD93u, 0xEFB5B8u, 0xECC3EBu,
    0xFFEEABu, 0xFFF1B5u, 0xFFF6D3u, 0xFFFFFFu
);

void fragment() {
    vec4 original_color = texture(screen_texture, SCREEN_UV);
    vec3 result_color = original_color.rgb;

    for (int i = 0; i < PALETTE_SIZE; i++) {
        vec3 target_rgb = hex_to_rgb(target_hex[i]);
        if (distance(original_color.rgb, target_rgb) < TOLERANCE) {
            result_color = hex_to_rgb(swap_hex[i]);
            break;
        }
    }

    COLOR = vec4(result_color, original_color.a);
}