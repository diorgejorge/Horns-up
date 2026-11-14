// Amostra uma textura em três planos do mundo, misturando pela normal.
// Serve para caixas grandes sem UV boa (paredes, chão, montanhas).
vec4 triplanar(sampler2D t, vec3 p, vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= (b.x + b.y + b.z);
	return texture(t, p.zy) * b.x + texture(t, p.xz) * b.y + texture(t, p.xy) * b.z;
}
