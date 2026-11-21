shader_type spatial;
// Onda no chão (Maré Curativa): anel que se abre com ondulações por dentro.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 cor : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float progresso : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float d = distance(UV, vec2(0.5)) * 2.0;     // 0 no centro, 1 na borda
	float r = progresso;
	float anel = smoothstep(0.08, 0.0, abs(d - r));
	float ondas = (0.5 + 0.5 * sin(d * 40.0 - TIME * 10.0)) * step(d, r) * 0.35;
	float some = 1.0 - progresso;
	ALBEDO = cor.rgb * 2.0;
	ALPHA = clamp((anel + ondas) * some * step(d, 1.0), 0.0, 1.0);
}
