shader_type sky;

// Sky gradient colors
uniform vec4 sky_top_color : source_color = vec4(0.02, 0.04, 0.12, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.06, 0.08, 0.22, 1.0);
uniform vec4 ground_color : source_color = vec4(0.01, 0.02, 0.05, 1.0);

// Nebula / Aurora colors
uniform vec4 nebula_color_1 : source_color = vec4(0.2, 0.05, 0.45, 1.0);
uniform vec4 nebula_color_2 : source_color = vec4(0.05, 0.25, 0.4, 1.0);
uniform float nebula_strength : hint_range(0.0, 2.0) = 0.45;

// Star parameters
uniform vec4 star_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
uniform float star_density : hint_range(10.0, 200.0) = 85.0;
uniform float twinkle_speed : hint_range(0.0, 10.0) = 2.5;
uniform float min_star_size : hint_range(0.001, 0.05) = 0.003;
uniform float max_star_size : hint_range(0.001, 0.05) = 0.012;

// Pseudo-random 2D hash
float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

// 2D Value Noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for nebula clouds
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.1;
		amplitude *= 0.5;
	}
	return value;
}

// Star grid layer
float star_layer(vec2 uv, float scale, float time) {
	vec2 gv = fract(uv * scale) - 0.5;
	vec2 id = floor(uv * scale);

	float h = hash21(id);
	// Random offset within the cell
	vec2 offset = vec2(h - 0.5, hash21(id + 13.7) - 0.5) * 0.7;
	float dist = length(gv - offset);

	// Twinkle factor using time and cell hash
	float twinkle = sin(time * twinkle_speed + h * 6.28318) * 0.5 + 0.5;
	float star_size = mix(min_star_size, max_star_size, h);

	// Sharp core and soft glow
	float star = smoothstep(star_size, 0.0, dist);
	star += smoothstep(star_size * 4.0, 0.0, dist) * 0.35;

	return star * mix(0.3, 1.0, twinkle) * step(0.65, h);
}

void sky() {
	// Spherical direction
	vec3 dir = EYEDIR;

	// Sky gradient factor based on elevation
	float elevation = dir.y;
	vec3 base_sky;
	if (elevation >= 0.0) {
		base_sky = mix(sky_horizon_color.rgb, sky_top_color.rgb, pow(clamp(elevation, 0.0, 1.0), 0.7));
	} else {
		base_sky = mix(sky_horizon_color.rgb, ground_color.rgb, pow(clamp(-elevation, 0.0, 1.0), 0.7));
	}

	// Equatorial coordinates projection for stars
	vec2 sky_uv = vec2(atan(dir.z, dir.x) / 6.283185 + 0.5, acos(clamp(dir.y, -1.0, 1.0)) / 3.141592);

	// Nebula clouds (only visible in the upper hemisphere)
	float sky_mask = smoothstep(-0.05, 0.25, elevation);
	float neb1 = fbm(sky_uv * 4.0 + vec2(0.05 * TIME * 0.02, 0.0));
	float neb2 = fbm(sky_uv * 6.0 - vec2(0.03 * TIME * 0.02, 0.02 * TIME * 0.02));
	vec3 nebula = (nebula_color_1.rgb * neb1 + nebula_color_2.rgb * neb2) * nebula_strength * sky_mask;

	// Multi-layer stars (small distant stars + closer bright twinkling stars)
	float stars = 0.0;
	if (elevation > -0.05) {
		float layer1 = star_layer(sky_uv, star_density, TIME);
		float layer2 = star_layer(sky_uv + vec2(0.33, 0.71), star_density * 1.7, TIME * 0.8);
		float layer3 = star_layer(sky_uv + vec2(0.57, 0.19), star_density * 0.6, TIME * 1.3);
		stars = (layer1 + layer2 * 0.6 + layer3 * 1.2) * sky_mask;
	}

	COLOR = base_sky + nebula + star_color.rgb * stars;
}

