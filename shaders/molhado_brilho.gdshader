// Brilho de chão molhado: escurece o chão e deixa ele liso/reflexivo.
// Desenhado por cima do próprio modelo (mesma malha), sem mexer no GLB.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform float umidade : hint_range(0.0, 1.0) = 0.8;
uniform vec3 cor_molhada : source_color = vec3(0.045, 0.03, 0.018);
uniform float escala_manchas = 1.7;

varying vec3 pos_mundo;
varying vec3 normal_mundo;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	VERTEX += NORMAL * 0.002; // evita briga de profundidade com o modelo original
	pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Mais molhado nas partes viradas para cima e em manchas irregulares.
	float topo = smoothstep(0.35, 0.9, normal_mundo.y);
	float manchas = ruido(pos_mundo.xz * escala_manchas) * 0.6 + ruido(pos_mundo.xz * escala_manchas * 3.1) * 0.4;
	float m = umidade * mix(0.55, 1.0, topo) * smoothstep(0.15, 0.75, manchas + umidade * 0.5);
	ALBEDO = cor_molhada;
	ALPHA = m * 0.7;
	ROUGHNESS = 0.18;
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
