shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;
uniform float darken_amount : hint_range(0.0, 1.0) = 0.6;

void fragment() {
    // Ambil warna layar di belakang ColorRect ini dan beri efek blur (Lod)
    vec4 blurred_color = textureLod(screen_texture, SCREEN_UV, blur_amount);
    
    // Gelapkan sedikit agar teks putih di depannya lebih terbaca (Premium look)
    COLOR = mix(blurred_color, vec4(0.0, 0.0, 0.0, 1.0), darken_amount);
}
