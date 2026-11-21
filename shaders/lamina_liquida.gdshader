// Lâmina de líquido (água ou lama) por cima de um tile.
// Ondulação, gotas de chuva, borda suave onde encosta no chão (usa a profundidade).
// Usa coordenadas do mundo: tiles vizinhos alagados emendam sem costura.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform vec3 cor_rasa : source_color = vec3(0.32, 0.27, 0.16);
uniform vec3 cor_funda : source_color = vec3(0.10, 0.09, 0.05);
uniform float opacidade : hint_range(0.0, 1.0) = 0.75;
uniform float profundidade_cor = 0.08;   // em metros: até onde a cor vai de rasa a funda
uniform float borda_suave = 0.012;       // em metros: transição onde o líquido encosta no chão
uniform float rugosidade : hint_range(0.0, 1.0) = 0.04;
uniform float forca_ondas : hint_range(0.0, 2.0) = 0.6;
uniform float velocidade : hint_range(0.0, 3.0) = 0.35;
uniform float chuva : hint_range(0.0, 1.0) = 0.0;     // anéis de gotas
uniform float pocas : hint_range(0.0, 1.0) = 1.0;     // 1 = cobre tudo, menor = só poças espalhadas
uniform float escala_pocas = 1.3;

uniform float espessura_max = 0.3;      // acima disso (em vista) considera que não há chão embaixo

uniform sampler2D tex_profundidade : hint_depth_texture, filter_linear, repeat_disable;

varying vec3 pos_mundo;

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
// Anéis de gota: uma gota por célula, em tempos diferentes.
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
	return ondas(p, t) * forca_ondas * 0.02 + gotas(p, t) * chuva * 0.012;
}

void vertex() {
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * velocidade;
	vec2 p = pos_mundo.xz;

	// Normal a partir da altura (diferenças finitas), em espaço do mundo -> vista.
	float e = 0.01;
	float h0 = altura(p, t);
	float hx = altura(p + vec2(e, 0.0), t);
	float hz = altura(p + vec2(0.0, e), t);
	vec3 n_mundo = normalize(vec3(h0 - hx, e, h0 - hz));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_mundo, 0.0)).xyz);

	// Quanto de líquido há entre a superfície e o chão (profundidade da cena).
	float d = texture(tex_profundidade, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	v.xyz /= v.w;
	float espessura = max(VERTEX.z - v.z, 0.0);
	// Câmera de cima em ângulo: converte distância na vista em altura aproximada.
	espessura *= abs(dot(normalize(VIEW), vec3(0.0, 0.0, 1.0)));

	float borda = smoothstep(0.0, borda_suave, espessura);
	// Sem chão embaixo (beira do tile, vão entre peças): some.
	float sem_chao = 1.0 - smoothstep(espessura_max * 0.6, espessura_max, espessura);
	float fundo = clamp(espessura / profundidade_cor, 0.0, 1.0);

	// Poças: recorte irregular pelo ruído do mundo.
	float mascara = 1.0;
	if (pocas < 0.999) {
		float r = ruido(p * escala_pocas) * 0.65 + ruido(p * escala_pocas * 2.7) * 0.35;
		mascara = smoothstep(1.0 - pocas, 1.0 - pocas + 0.08, r);
	}

	ALBEDO = mix(cor_rasa, cor_funda, fundo);
	ALPHA = mix(opacidade * 0.65, opacidade, fundo) * borda * mascara * sem_chao;
	// Rugosidade muito baixa + glow pode estourar em placas de vídeo reais (quadrados pretos).
	ROUGHNESS = max(rugosidade, 0.14);
	SPECULAR = 0.45;
	METALLIC = 0.0;
}
