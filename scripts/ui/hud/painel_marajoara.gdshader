shader_type canvas_item;
// Painel de madeira escura com moldura de grafismo marajoara (degraus em
// vermelho, preto e creme). A madeira e a argila da moldura usam texturas
// fotográficas CC0 do Poly Haven (assets/diorge/ui/texturas, ver CREDITS.md),
// com normal map para o relevo; o grafismo continua procedural.
// Usado por PainelMarajoara (scripts/ui/hud/painel_marajoara.gd), que passa o
// tamanho do painel em pixels para o desenho não esticar.

uniform vec2 tamanho = vec2(300.0, 200.0);
uniform float borda = 12.0;          // largura da faixa da moldura, em px
uniform vec4 madeira : source_color = vec4(0.20, 0.12, 0.07, 0.95);
uniform vec4 vermelho : source_color = vec4(0.66, 0.18, 0.10, 1.0);
uniform vec4 preto : source_color = vec4(0.08, 0.05, 0.04, 1.0);
uniform vec4 creme : source_color = vec4(0.94, 0.87, 0.70, 1.0);
uniform vec4 destaque : source_color = vec4(0.66, 0.18, 0.10, 1.0); // cor da faixa (vermelho ou ouro)
uniform float semente = 0.0;
uniform float pulso = 0.0;          // 0..1: brilho pulsante (painel selecionado)
uniform sampler2D madeira_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D madeira_nor : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D argila_tex : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D argila_nor : hint_normal, repeat_enable, filter_linear_mipmap;
uniform float escala_tex = 420.0;    // pixels da tela por repetição da textura

// Luz do canto de cima à esquerda, no espaço do normal map (OpenGL, +Y para cima).
float luz(sampler2D nor, vec2 uv) {
	vec3 n = texture(nor, uv).rgb * 2.0 - 1.0;
	return dot(normalize(n), normalize(vec3(-0.45, 0.55, 0.75)));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// Degrau marajoara: triângulo escalonado em 3 degraus, alternando para cima e
// para baixo. t = posição ao longo da faixa (px), s = 0..1 através da faixa.
float degrau(float t, float s, float alt) {
	float periodo = alt * 3.2;
	float k = floor(t / (periodo * 0.5));
	float x = fract(t / (periodo * 0.5));
	float h = (floor(x * 3.0) + 1.0) / 3.0;   // 1/3, 2/3, 1
	if (mod(k, 2.0) > 0.5) {
		s = 1.0 - s;
	}
	return step(s, h * 0.86);
}

void fragment() {
	vec2 px = UV * tamanho;
	// --- madeira: textura real escurecida para o tom do painel, com relevo dos veios
	vec2 uvt = px / escala_tex + vec2(semente * 0.37, semente * 0.11);
	vec3 foto = texture(madeira_tex, uvt).rgb;
	vec4 cor = vec4(foto * madeira.rgb * 2.1, madeira.a);
	cor.rgb *= 0.82 + 0.3 * luz(madeira_nor, uvt);
	// sombra interna perto da moldura
	float d = min(min(px.x, tamanho.x - px.x), min(px.y, tamanho.y - px.y));
	cor.rgb *= mix(0.72, 1.0, smoothstep(borda, borda + 18.0, d));

	// brilho de verniz no alto do painel (luz vindo de cima, visual 3D moderno)
	float topo = 1.0 - smoothstep(0.0, tamanho.y * 0.45, px.y - borda);
	cor.rgb += vec3(1.0, 0.85, 0.6) * topo * 0.07;

	// --- moldura
	if (d < borda) {
		float s = d / borda;                    // 0 na borda externa, 1 na interna
		bool horizontal = min(px.y, tamanho.y - px.y) <= min(px.x, tamanho.x - px.x);
		float t = horizontal ? px.x : px.y;
		cor = destaque;
		if (degrau(t, (s - 0.18) / 0.64, borda) > 0.5 && s > 0.18 && s < 0.82) {
			cor = creme;
		}
		if (s < 0.14 || s > 0.86) {
			cor = preto;
		}
		// cantos: losango creme sobre preto
		vec2 c = vec2(min(px.x, tamanho.x - px.x), min(px.y, tamanho.y - px.y));
		if (c.x < borda && c.y < borda) {
			vec2 q = abs(c - vec2(borda * 0.5));
			cor = (q.x + q.y < borda * 0.32) ? creme : preto;
		}
		// relevo: a moldura é um bisel, iluminado em cima/esquerda e sombreado
		// embaixo/direita, como uma peça de cerâmica em alto-relevo.
		vec2 lado = vec2(px.x < tamanho.x * 0.5 ? -1.0 : 1.0, px.y < tamanho.y * 0.5 ? -1.0 : 1.0);
		bool perto_x = min(px.x, tamanho.x - px.x) < min(px.y, tamanho.y - px.y);
		float face = perto_x ? -lado.x : -lado.y;          // +1 voltado para a luz
		float curva = sin(s * 3.14159);                    // arredondado no meio da faixa
		cor.rgb *= 1.0 + face * 0.22 * (1.0 - curva * 0.5);
		// cerâmica: grão da argila na pintura e o relevo do normal map
		vec2 uva = px / (escala_tex * 0.6);
		float grao = dot(texture(argila_tex, uva).rgb, vec3(0.333));
		cor.rgb *= 0.55 + grao * 1.15;
		cor.rgb *= 0.85 + 0.3 * luz(argila_nor, uva);
		cor.rgb += vec3(1.0, 0.9, 0.7) * pow(curva, 6.0) * 0.12 * max(face, 0.0);
		// pulso dourado no painel selecionado
		cor.rgb += destaque.rgb * pulso * (0.18 + 0.12 * sin(TIME * 3.0));
	} else {
		// fio de luz logo dentro da moldura (sombra interna no lado de baixo)
		float dentro = d - borda;
		cor.rgb += vec3(1.0, 0.8, 0.5) * (1.0 - smoothstep(0.0, 2.0, dentro)) * 0.12 * pulso;
	}
	COLOR = cor;
}
