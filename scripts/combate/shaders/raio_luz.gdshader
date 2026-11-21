shader_type spatial;
// Raio de luz do clérigo: cilindro aditivo com faixas que correm do lançador ao alvo.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 cor : source_color = vec4(1.0, 0.8, 0.9, 1.0);
uniform float forca = 1.0;      // 0..1, a batalha anima para sumir
uniform float faixas = 14.0;

void fragment() {
	float borda = pow(abs(dot(NORMAL, VIEW)), 1.6);
	float corre = 0.65 + 0.35 * sin(UV.y * faixas * 6.2832 - TIME * 24.0);
	float a = borda * corre * forca;
	ALBEDO = mix(cor.rgb, vec3(1.0), borda * 0.6) * 2.5;
	ALPHA = clamp(a, 0.0, 1.0);
}
