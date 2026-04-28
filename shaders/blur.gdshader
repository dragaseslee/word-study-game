shader_type canvas_item;

uniform float blur_strength : hint_range(0.0, 10.0) = 3.0;

void fragment() {
    vec2 ps = TEXTURE_PIXEL_SIZE * blur_strength;

    vec4 col = vec4(0.0);
    col += texture(TEXTURE, UV + vec2(-ps.x, -ps.y)) * 1.0;
    col += texture(TEXTURE, UV + vec2( 0.0,   -ps.y)) * 2.0;
    col += texture(TEXTURE, UV + vec2( ps.x, -ps.y)) * 1.0;
    col += texture(TEXTURE, UV + vec2(-ps.x,  0.0))  * 2.0;
    col += texture(TEXTURE, UV)                      * 4.0;
    col += texture(TEXTURE, UV + vec2( ps.x,  0.0))  * 2.0;
    col += texture(TEXTURE, UV + vec2(-ps.x,  ps.y)) * 1.0;
    col += texture(TEXTURE, UV + vec2( 0.0,   ps.y)) * 2.0;
    col += texture(TEXTURE, UV + vec2( ps.x,  ps.y)) * 1.0;

    COLOR = col / 16.0;
}