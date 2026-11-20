shader_type spatial;
// Pós-processo de contorno escuro (estilo pintado), aplicado num quad que cobre a tela.
// Detecta bordas por diferença de profundidade e de normal.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.10, 0.07, 0.05, 1.0);
uniform float thickness = 1.3;      // em pixels
uniform float depth_threshold = 0.25;
uniform float normal_threshold = 0.6;
uniform float strength = 0.85;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 view_normal(vec2 uv) {
	return texture(normal_tex, uv).xyz * 2.0 - 1.0;
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float dc = view_depth(uv, INV_PROJECTION_MATRIX);
	vec3 nc = view_normal(uv);
	float edge = 0.0;
	vec2 offs[4] = vec2[](vec2(px.x, 0.0), vec2(-px.x, 0.0), vec2(0.0, px.y), vec2(0.0, -px.y));
	for (int i = 0; i < 4; i++) {
		float d = view_depth(uv + offs[i], INV_PROJECTION_MATRIX);
		// só desenha do lado de trás da borda, para o traço ficar fino
		edge = max(edge, step(depth_threshold, d - dc));
		vec3 n = view_normal(uv + offs[i]);
		edge = max(edge, step(normal_threshold, 1.0 - dot(nc, n)) * 0.6);
	}
	// Só desenha a linha (com alpha). Com render_priority baixo este quad é o
	// primeiro transparente: água, partículas e nomes ficam por cima dele.
	ALBEDO = line_color.rgb;
	ALPHA = edge * strength;
}
