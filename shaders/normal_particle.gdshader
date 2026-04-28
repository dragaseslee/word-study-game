shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 glow_color : source_color = vec4(0.45, 1.0, 0.35, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float ray_count : hint_range(4.0, 32.0) = 10.0;
uniform float intensity : hint_range(0.0, 5.0) = 1.8;

uniform sampler2D noise_tex;
uniform float noise_scale = 2.5;
uniform float angle_noise_strength : hint_range(0.0, 2.0) = 0.35;
uniform float edge_noise_strength : hint_range(0.0, 1.0) = 0.18;
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.12;
uniform float time_speed = 1.5;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    // 角度映射到 0~1，方便采样噪声
    float angle01 = (a + 3.1415926) / 6.2831852;

    // -------------------------
    // 1) 角向噪声：让每个方向的光束不均匀
    // -------------------------
    float angle_noise = texture(
        noise_tex,
        vec2(angle01 * noise_scale, TIME * 0.12)
    ).r;

    float angle_offset = (angle_noise - 0.5) * angle_noise_strength;

    // 扰动后的角度
    float warped_a = a + angle_offset;

    // 基础射线
    float base_ray = max(0.0, cos(warped_a * ray_count));

    // 不让射线太机械：亮度再乘一个角向随机值
    float angle_brightness = texture(
        noise_tex,
        vec2(angle01 * noise_scale * 0.7 + 1.7, 0.23)
    ).r * 0.6 + 0.4;

    float ray = pow(base_ray, 7.0) * angle_brightness;

    // -------------------------
    // 2) 边缘破碎：让爆光外轮廓不规则
    // -------------------------
    float edge_noise = texture(
        noise_tex,
        uv * 0.5 * noise_scale + vec2(TIME * 0.08, TIME * 0.05)
    ).r;

    float edge_offset = (edge_noise - 0.5) * edge_noise_strength;

    // 中心核
    float core = smoothstep(0.34, 0.0, r);

    // 带破碎边缘的外层爆光
    float burst_radius = 0.82 + edge_offset;
    float burst_mask = smoothstep(burst_radius, 0.08, r);

    // 射线只在中外层更明显
    float ray_mask = smoothstep(0.95, 0.18, r) * smoothstep(0.02, 0.16, r);
    float burst = ray * ray_mask * burst_mask;

    // -------------------------
    // 3) 局部明暗不均：让内部更“活”
    // -------------------------
    float detail_noise = texture(
        noise_tex,
        uv * noise_scale * 1.4 + vec2(TIME * 0.15, -TIME * 0.11)
    ).r;

    float detail = mix(0.8, 1.2, detail_noise);

    // 柔和光晕
    float halo = smoothstep(1.0, 0.18, r) * 0.35;

    // -------------------------
    // 4) 时间闪烁：非常轻，不要过头
    // -------------------------
    float flicker_noise = texture(
        noise_tex,
        vec2(TIME * time_speed, 0.73)
    ).r;

    float flicker = mix(1.0 - flicker_strength, 1.0 + flicker_strength, flicker_noise);

    // 整体衰减
    float fade = 1.0 - progress;

    float alpha = (core * 1.15 + burst * 1.0 + halo) * detail * fade * flicker;
    vec3 col = glow_color.rgb * alpha * intensity;

    COLOR = vec4(col, alpha);
}