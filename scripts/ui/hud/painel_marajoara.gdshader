shader_type canvas_item;
// Painel de madeira escura com moldura de grafismo marajoara (degraus em
// vermelho, preto e creme). Todo procedural: não usa imagem nenhuma.
// Usado por PainelMarajoara (scripts/ui/hud/painel_marajoara.gd), que passa o
// tamanho do painel em pixels para o desenho não esticar.

uniform vec2 tamanho = vec2(300.0, 200.0);
uniform float borda = 12.0;          // largura da faixa da moldura, em px
uniform vec4 madeira : source_color = vec4(0.20, 0.12, 0.07, 0.95);
uniform vec4 veio : source_color = vec4(0.11, 0.065, 0.04, 1.0);
uniform vec4 vermelho : source_color = vec4(0.66, 0.18, 0.10, 1.0);
uniform vec4 preto : source_color = vec4(0.08, 0.05, 0.04, 1.0);
uniform vec4 creme : source_color = vec4(0.94, 0.87, 0.70, 1.0);
uniform vec4 destaque : source_color = vec4(0.66, 0.18, 0.10, 1.0); // cor da faixa (vermelho ou ouro)
uniform float semente = 0.0;
uniform float pulso = 0.0;          // 0..1: brilho pulsante (painel selecionado)

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
	// --- madeira: veios longos na horizontal, distorcidos por ruído
	float n = ruido(vec2(px.x * 0.012, px.y * 0.18) + semente);
	float veios = sin(px.y * 0.35 + n * 7.0 + ruido(px * 0.02) * 4.0);
	float linha = smoothstep(0.75, 1.0, veios);
	vec4 cor = mix(madeira, veio, linha * 0.55 + ruido(px * vec2(0.004, 0.05)) * 0.25);
	cor.a = madeira.a;
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
