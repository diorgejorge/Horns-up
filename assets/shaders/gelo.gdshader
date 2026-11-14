shader_type spatial;
// Gelo: refrata o que está atrás, rachaduras em várias profundidades
// (parallax), borda clara pelo fresnel, reflexo duro e geada no topo.
render_mode blend_mix, depth_draw_always, cull_back;
#include "res://assets/shaders/triplanar.gdshaderinc"

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D rachaduras : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D relevo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 cor_funda : source_color = vec3(0.04, 0.27, 0.50);
uniform vec3 cor_rasa : source_color = vec3(0.55, 0.88, 1.0);
uniform vec3 cor_geada : source_color = vec3(0.90, 0.96, 1.0);
uniform float escala = 0.09;
uniform float refracao = 0.035;
uniform float profundidade = 0.6;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 p = wpos * escala;
	vec3 nm = triplanar(relevo, p, wnrm).rgb;
	// rachaduras em 4 camadas, cada uma mais funda e mais apagada
	float rach = 0.0;
	for (int k = 0; k < 3; k++) {
		float d = float(k) * profundidade;
		vec3 q = (wpos - vw * d) * escala * (1.0 + 0.35 * float(k));
		float c = triplanar(rachaduras, q, wnrm).r;
		rach += (1.0 - smoothstep(0.02, 0.1, c)) * (0.8 - 0.25 * float(k));
	}
	rach = clamp(rach, 0.0, 1.0);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec2 desvio = (nm.rg - 0.5) * refracao;
	vec3 atras = textureLod(tela, SCREEN_UV + desvio, 1.5).rgb;
	// mais fundo no meio, mais claro na borda
	vec3 corpo = mix(atras * cor_rasa, cor_funda, 0.62 - fres * 0.3);
	float geada = smoothstep(0.6, 0.85, wnrm.y);
	ALBEDO = mix(corpo + rach * vec3(0.55, 0.75, 0.85), cor_geada, geada);
	EMISSION = (fres * vec3(0.45, 0.75, 1.0) + rach * vec3(0.12, 0.25, 0.35)) * (1.0 - geada);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = mix(0.06, 0.6, geada);
	SPECULAR = 0.8;
	ALPHA = 1.0;
}
