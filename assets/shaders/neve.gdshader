shader_type spatial;
// Neve fofa no topo (com cintilar que muda com o ângulo da câmera) e
// camadas de neve compactada e gelo nas laterais.
#include "res://assets/shaders/triplanar.gdshaderinc"

uniform sampler2D relevo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D brilho : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 cor_neve : source_color = vec3(0.94, 0.97, 1.0);
uniform vec3 cor_sombra : source_color = vec3(0.70, 0.80, 0.95);
uniform vec3 cor_camadas : source_color = vec3(0.55, 0.68, 0.84);
uniform float escala = 0.35;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = wpos * escala;
	vec3 n = triplanar(relevo, p, wnrm).rgb;
	float ondula = n.r;
	float topo = smoothstep(0.4, 0.8, wnrm.y);
	float camadas = 0.5 + 0.5 * sin(wpos.y * 9.0 + ondula * 4.0);
	vec3 lado = mix(cor_camadas, cor_sombra, camadas * 0.6);
	vec3 cima = mix(cor_sombra, cor_neve, smoothstep(0.3, 0.7, ondula * 0.8 + n.g * 0.2));
	ALBEDO = mix(lado, cima, topo);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.6;
	ROUGHNESS = mix(0.35, 0.75, topo);
	// cintilar: dois grãos que só coincidem em certos ângulos de visão
	vec3 vw = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	float g1 = triplanar(brilho, wpos * 1.3, wnrm).r;
	float g2 = triplanar(brilho, wpos * 1.3 + vw * 0.08, wnrm).r;
	float cintila = step(0.92, g1 * g2 * 1.6) * topo;
	EMISSION = vec3(1.2, 1.3, 1.5) * cintila;
}
