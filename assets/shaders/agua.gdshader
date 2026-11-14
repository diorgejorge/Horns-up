shader_type spatial;
// Água fria de lago: ondas no vértice, ondinhas por normal map que correm em
// duas direções, refração do fundo, céu refletido pelo fresnel, brilho do sol
// e espuma junto da margem (z perto de `margem_z`).
render_mode blend_mix, depth_draw_always, cull_disabled;

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D ondas : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D espuma_ruido : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 cor_funda : source_color = vec3(0.01, 0.07, 0.15);
uniform vec3 cor_rasa : source_color = vec3(0.12, 0.42, 0.55);
uniform vec3 cor_ceu : source_color = vec3(0.42, 0.58, 0.74);
// meia largura do chão em z: a espuma fica junto das duas margens
uniform float margem_z = 2.0;
uniform float velocidade = 0.6;

varying vec3 wpos;

float onda(vec2 p, float t) {
	return 0.06 * sin(p.x * 0.9 + t * 1.3) + 0.04 * sin(p.y * 1.7 - t * 1.1)
		+ 0.025 * sin((p.x + p.y) * 2.3 + t * 2.0);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * velocidade;
	float h = onda(w.xz, t);
	float e = 0.05;
	float hx = onda(w.xz + vec2(e, 0.0), t);
	float hz = onda(w.xz + vec2(0.0, e), t);
	VERTEX.y += h;
	NORMAL = normalize(vec3(h - hx, e, h - hz));
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * velocidade;
	vec3 n1 = texture(ondas, wpos.xz * 0.11 + vec2(t * 0.02, t * 0.013)).rgb;
	vec3 n2 = texture(ondas, wpos.xz * 0.23 - vec2(t * 0.017, -t * 0.021)).rgb;
	vec3 nm = normalize(mix(n1, n2, 0.5) * 2.0 - 1.0) * 0.5 + 0.5;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	vec2 desvio = (nm.rg - 0.5) * 0.06;
	vec3 atras = textureLod(tela, SCREEN_UV + desvio, 1.0).rgb;
	vec3 agua = mix(cor_funda, atras * cor_rasa * 1.6, 0.35);
	agua = mix(agua, cor_ceu, clamp(fres * 0.6 + 0.08, 0.0, 0.7));
	// espuma na margem, quebrada pelo ruído e mexendo com o tempo
	float perto = 1.0 - smoothstep(0.0, 1.4, abs(wpos.z) - margem_z);
	float ruido = texture(espuma_ruido, wpos.xz * 0.12 + vec2(t * 0.03, 0.0)).r;
	float espuma = smoothstep(0.5 - perto * 0.3, 0.62 - perto * 0.3, ruido) * perto;
	ALBEDO = mix(agua, vec3(0.92, 0.96, 1.0), espuma);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = mix(0.04, 0.7, espuma);
	SPECULAR = 0.9;
	ALPHA = mix(0.9, 1.0, espuma);
}
