float pixelWidth = 1.0 / viewWidth;
float pixelHeight = 1.0 / viewHeight;

vec3 getBloomTile(float lod, vec2 bloomCoord, vec2 offset) {
	float scale = exp2(lod);

	float resScale = 1.25 * min(360.0, viewHeight) / viewHeight;
	vec3 bloom = texture2DLod(colortex1, (bloomCoord / scale + offset) * resScale, 0.0).rgb;

	return pow8(bloom) * 256.0;
}

void getBloom(inout vec3 color, vec2 coord, float z1) {
	float eBS = eyeBrightnessSmooth.y / 240.0;
	vec2 viewSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);
	vec3 blur1 = getBloomTile(1.0 + BLOOM_TILE_SIZE, coord, vec2(0.0   , 0.0 ) + vec2( 0.5, 0.0) * viewSize);
	vec3 blur2 = getBloomTile(2.0 + BLOOM_TILE_SIZE, coord, vec2(0.50  , 0.0 ) + vec2( 4.5, 0.0) * viewSize);
	vec3 blur3 = getBloomTile(3.0 + BLOOM_TILE_SIZE, coord, vec2(0.50  , 0.25) + vec2( 4.5, 4.0) * viewSize);
	vec3 blur4 = getBloomTile(4.0 + BLOOM_TILE_SIZE, coord, vec2(0.625 , 0.25) + vec2( 8.5, 4.0) * viewSize);

	vec3 blur = (blur1 * 2.46 + blur2 * 2.25 + blur3 * 1.71 + blur4) / 7.42;
	
	float bloomStrength = BLOOM_STRENGTH;

	#ifdef OVERWORLD
	#ifdef AURORA_3_7
	//3.7: moonlight strongly boosts the bloom on the sky (z1==1.0), giving the aurora its soft radial
	//glow. Classic's BLOOM_STRENGTH is 1.25 vs 3.7's 1.0 base, so scale the moon boost by 0.6 to
	//keep the full-moon sky bloom at the 3.7 level (~2.0). AURORA_BLOOM is a debug control for the
	//aurora blur/bloom strength (0 = no glow, higher = stronger).
	bloomStrength *= 1.0 + float(z1 == 1.0) * moonVisibility * 0.6 * AURORA_BLOOM;
	#else
	bloomStrength *= 1.0 - timeBrightness * 0.33 * eBS;
	#endif
	#endif

	#if BLOOM_CONTRAST == 0
	color = mix(color, blur, 0.25 * bloomStrength);
	#else
	vec3 bloomContrast = vec3(exp2(BLOOM_CONTRAST * 0.25));
	color = pow(color, bloomContrast);
	blur = pow(blur, bloomContrast);
	vec3 strengthFactor = pow(vec3(0.2 * bloomStrength), bloomContrast) * (1.5 - eBS * 0.5);
	color = mix(color, blur, strengthFactor);
	color = pow(color, 1.0 / bloomContrast);
	#endif
}