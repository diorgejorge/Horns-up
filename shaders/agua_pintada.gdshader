// Dá vida à água que já está PINTADA na textura do tile (poça, mangue, riacho...).
// Desenhado por cima do próprio modelo (mesma malha). Só age onde a cor da
// textura parece água (azulada/esverdeada); terra, pedra e folhas ficam como estão.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform float limiar = 0.03;            // quanto "mais azul que vermelho" a cor precisa ser
uniform float forca_ondas : hint_range(0.0, 2.0) = 1.2;
uniform float velocidade : hint_range(0.0, 3.0) = 0.35;
uniform float chuva : hint_range(0.0, 1.0) = 0.0;
uniform float distorcao = 0.03;        // quanto a imagem da água "balança"
uniform float brilho : hint_range(0.0, 1.0) = 0.75;

varying vec3 pos_mundo;
varying vec3 normal_mundo;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float ondas(vec2 p, float t) {
	return ruido(p * 3.0 + vec2(t, t * 0.7)) * 0.5
		+ ruido(p * 6.5 - vec2(t * 1.3, -t * 0.4)) * 0.3
		+ ruido(p * 13.0 + vec2(-t * 0.6, t * 1.7)) * 0.2;
}
float gotas(vec2 p, float t) {
	float h = 0.0;
	vec2 c = floor(p * 2.5);
	for (int y = -1; y <= 1; y++) for (int x = -1; x <= 1; x++) {
		vec2 cel = c + vec2(float(x), float(y));
		vec2 r = hash2(cel);
		vec2 centro = (cel + r) / 2.5;
		float fase = fract(t * 0.6 + r.x * 7.0);
		float d = length(p - centro);
		float raio = fase * 0.35;
		h += sin(clamp((d - raio) * 70.0, -3.1416, 3.1416)) * (1.0 - fase) * smoothstep(0.02, 0.0, abs(d - raio));
	}
	return h;
}
float altura(vec2 p, float t) {
	return ondas(p, t) * forca_ondas * 0.02 + gotas(p, t) * chuva * 0.03;
}

void vertex() {
	VERTEX += NORMAL * 0.002;
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 cor = texture(tex_albedo, UV).rgb;
	float agua = smoothstep(limiar, limiar + 0.06, cor.b - cor.r) * smoothstep(0.6, 0.85, normal_mundo.y);

	float t = TIME * velocidade;
	vec2 p = pos_mundo.xz;
	float e = 0.01;
	float h0 = altura(p, t);
	vec3 n_mundo = normalize(vec3(h0 - altura(p + vec2(e, 0.0), t), e, h0 - altura(p + vec2(0.0, e), t)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_mundo, 0.0)).xyz);

	vec3 cor_mexida = texture(tex_albedo, UV + n_mundo.xz * distorcao).rgb;
	ALBEDO = cor_mexida * 0.92;
	ALPHA = agua;
	// Rugosidade muito baixa + glow pode estourar em placas reais (quadrados pretos).
	ROUGHNESS = 0.16;
	SPECULAR = brilho;
	METALLIC = 0.0;
}
