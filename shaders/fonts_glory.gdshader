shader_type canvas_item;

uniform float glow_size : hint_range(0.0, 16.0, 0.1) = 4.0;
uniform float glow_strength : hint_range(0.0, 4.0, 0.01) = 1.2;
uniform int sample_count : hint_range(4, 24, 1) = 12;

const int MAX_SAMPLES = 24;

void fragment() {
    vec4 base = texture(TEXTURE, UV) * COLOR;
    float base_alpha = base.a;

    // 直接使用当前文字颜色作为光晕颜色
    vec3 glow_color = COLOR.rgb;

    float glow_accum = 0.0;
    float weight_accum = 0.0;

    // 环形多方向采样，做一个轻量柔光
    for (int i = 0; i < MAX_SAMPLES; i++) {
        if (i >= sample_count) {
            break;
        }

        float angle = TAU * float(i) / float(sample_count);
        vec2 dir = vec2(cos(angle), sin(angle));

        // 从内到外采样几层
        for (int s = 1; s <= 4; s++) {
            float t = float(s) / 4.0;
            vec2 offset = dir * TEXTURE_PIXEL_SIZE * glow_size * t;

            float a = texture(TEXTURE, UV + offset).a;
            float w = 1.0 - t; // 越靠近文字权重越高

            glow_accum += a * w;
            weight_accum += w;
        }
    }

    float glow_alpha = 0.0;
    if (weight_accum > 0.0) {
        glow_alpha = (glow_accum / weight_accum) * glow_strength;
    }

    // 不让内部文字被“重复加厚”
    glow_alpha = max(glow_alpha - base_alpha, 0.0);

    float final_alpha = max(base_alpha, glow_alpha);

    vec3 final_rgb;
    if (final_alpha > 0.0001) {
        final_rgb =
            (glow_color * glow_alpha * (1.0 - base_alpha) + base.rgb * base_alpha)
            / final_alpha;
    } else {
        final_rgb = vec3(0.0);
    }

    COLOR = vec4(final_rgb, final_alpha);
}