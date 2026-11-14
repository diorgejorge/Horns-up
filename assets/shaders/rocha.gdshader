shader_type spatial;
// Rocha com estratos, grão fino e neve acumulada no que é de cima.
#include "res://assets/shaders/triplanar.gdshaderinc"

uniform sampler2D ruido : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D relevo : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 cor_escura : source_color = vec3(0.10, 0.10, 0.12);
uniform vec3 cor_clara : source_color = vec3(0.34, 0.34, 0.37);
uniform vec3 cor_neve : source_color = vec3(0.93, 0.96, 1.0);
uniform float escala = 0.3;
// Quanto a face precisa olhar para cima para juntar neve (1 = só o topo).
uniform float neve_topo = 0.65;
// Acima desta altura do mundo, neve em tudo (picos das montanhas).
uniform float neve_altura = 1000.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = wpos * escala;
	float r = triplanar(ruido, p, wnrm).r;
	float fino = triplanar(ruido, p * 6.0, wnrm).r;
	float estratos = 0.5 + 0.5 * sin(wpos.y * 2.6 + r * 7.0);
	vec3 c = mix(cor_escura, cor_clara, smoothstep(0.2, 0.8, r * 0.65 + fino * 0.35));
	c *= 0.8 + 0.2 * estratos;
	float neve = smoothstep(neve_topo, neve_topo + 0.12, wnrm.y + (r - 0.5) * 0.5);
	neve = max(neve, smoothstep(neve_altura, neve_altura + 2.5, wpos.y + (r - 0.5) * 6.0));
	ALBEDO = mix(c, cor_neve, neve);
	NORMAL_MAP = triplanar(relevo, p * 1.7, wnrm).rgb;
	NORMAL_MAP_DEPTH = mix(1.4, 0.4, neve);
	ROUGHNESS = mix(0.92, 0.55, neve);
}
