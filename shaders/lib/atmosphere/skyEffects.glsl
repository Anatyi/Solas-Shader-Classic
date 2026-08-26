//End Revolution helpers//
#ifdef PORT_END_ON
float getEnhEndTimeFactor() {
    return fract(frameTimeCounter * ((1.0 / 60.0) / ENH_END_REVOLUTION_CYCLE) + ENH_END_START_ANGLE / 360.0) * TAU;
}
vec3 enhEndRotateY(vec3 dir, float ang) {
    float c = cos(ang);
    float s = sin(ang);
    return vec3(dir.x * c - dir.z * s, dir.y, dir.x * s + dir.z * c);
}
#endif

#ifdef PORT_END_LENS_ON
//Gravitational lensing: bend ray directions near the black hole into a vortex swirl
vec3 enhEndLensWarp(vec3 dir, vec3 bhViewDir) {
	vec3 d = normalize(dir);
	float ang = dot(d, bhViewDir);
	//Wide smooth falloff so the warp is clearly visible around the black hole
	float falloff = exp(-(1.0 - ang) * 4.0);
	vec3 tangent = normalize(cross(bhViewDir, vec3(0.0, 1.0, 0.0)) + 0.0001);
	vec3 bitangent = cross(bhViewDir, tangent);
	//Stronger vortex swirl + radial lensing
	d = normalize(d + (tangent * 0.22 + bitangent * 0.12 + bhViewDir * 0.28) * ENH_END_LENS_STRENGTH * falloff);
	return d * length(dir);
}
#endif

#if defined STARS || defined END_STARS
float getNoise(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

void drawStars(inout vec3 color, in vec3 worldPos, inout vec3 stars, in float VoU, in float caveFactor, in float nebulaFactor, in float volumetricClouds, float size, in float blackHoleDim, in float bhLensRing, in float bhLensSize) {
	#ifdef OVERWORLD
	float visibility = mix(0.5, 0.5 - timeBrightnessSqrt * 0.5, sunVisibility) * (1.0 - wetness) * (1.0 - volumetricClouds) * pow(VoU, 0.5) * caveFactor;
	float starQuantity = STAR_AMOUNT;
	float starDensity = STAR_DENSITY;
	float starBrightness = STAR_BRIGHTNESS;
	float starSize = STAR_SIZE;
	#else
	float visibility = 0.4 - nebulaFactor * 0.2;
	float starQuantity = END_STAR_AMOUNT;
	float starDensity = END_STAR_DENSITY;
	float starBrightness = END_STAR_BRIGHTNESS;
	float starSize = END_STAR_SIZE;
	visibility *= blackHoleDim; //3.7 black hole: caller dims the stars around the hole (sun direction)
	#endif

	if (visibility > 0.0) {
		vec2 planeCoord = worldPos.xz / (length(worldPos.y) + length(worldPos.xz));
			 planeCoord *= size;
			 #if defined END_BLACK_HOLE_3_7 || defined END_VORTEX_LENS
			 //3.7 black hole gravitational lensing: Einstein ring push + vortex spiral shear so
			 //nearby stars swirl inward around the hole (3.7 hole or the 2.3 vortex lens).
			 planeCoord *= clamp(1.0 - bhLensRing * 4.0, 0.0, 1.0);
			 planeCoord += bhLensRing;
			 vec2 bhCenter = vec2(bhLensRing);
			 vec2 bhRel = planeCoord - bhCenter;
			 float bhR = length(bhRel);
			 //Vortex radius follows the black hole size control (3.7 concept: small size value =
			 //big hole = wider vortex). bhR lives on the star-plane scale (roughly 0..0.3 after
			 //the *size projection), so map the radius into that range for a visible falloff.
			 float bhVortexRange = mix(0.08, 0.45, (3.0 - bhLensSize) / 2.75);
			 #ifdef END_VORTEX_LENS
			 //Gravitational distortion range: radius uses the absolute value so the falloff always
			 //decays outward; the sign flips the rotation direction (kept separate from strength).
			 float bhGravityRange = END_VORTEX_LENS_GRAVITY_RANGE;
			 bhVortexRange *= abs(bhGravityRange);
			 #endif
			 float bhShear = bhLensRing * 6.0 * pow2(clamp(1.0 - bhR / bhVortexRange, 0.0, 1.0));
			 #ifdef END_VORTEX_LENS
			 //2.3 gravitational distortion strength: scales the shear directly; negative values
			 //reverse the vortex rotation direction.
			 bhShear *= END_VORTEX_LENS_GRAVITY * sign(bhGravityRange);
			 #endif
			 float bhCos = cos(bhShear);
			 float bhSin = sin(bhShear);
			 planeCoord = bhCenter + mat2(bhCos, bhSin, -bhSin, bhCos) * bhRel;
			 #endif
			 planeCoord += cameraPosition.xz * 0.00001;
			 planeCoord += frameTimeCounter * 0.001;
			 planeCoord = floor(planeCoord * 1024.0 * starQuantity) / (1024.0 * starQuantity);

		float threshold = (0.75 - nebulaFactor * 0.1) / max(starDensity, 0.01);

		float star = getNoise(planeCoord);
			  star*= getNoise(planeCoord + 0.10);
			  star*= getNoise(planeCoord + 0.23);
			  star = clamp(star - threshold, 0.0, 1.0);

		//Star size: sample nearby grid cells so each star covers a small disc (size in grid units).
		float starRadius = max(starSize - 1.0, 0.0) / (1024.0 * starQuantity);
		if (starRadius > 0.0) {
			for (int i = 0; i < 6; i++) {
				float ang = (float(i) / 6.0) * TAU;
				vec2 off = vec2(cos(ang), sin(ang)) * starRadius;
				float s = getNoise(planeCoord + off) * getNoise(planeCoord + off + 0.10) * getNoise(planeCoord + off + 0.23);
				star = max(star, clamp(s - threshold, 0.0, 1.0));
			}
		}

		stars = vec3(star * visibility * starBrightness * 8.0);
		color += stars;
	}
}
#endif

#ifdef MILKY_WAY
//Generated night nebula (3.7 noise cloud layer that drifts with the starfield and blends with the
//aurora). Independent of SKY_3_7 so it can be toggled on its own.
#ifdef GENERATED_NIGHT_NEBULA
void drawGeneratedNightNebula(inout vec3 color, in vec3 worldPos, in float caveFactor, in float auroraOcclusion) {
	vec3 nWorldPos = normalize(worldPos);
	float VoM = clamp(dot(normalize(worldPos), -sunVec), 0.0, 1.0);
	float VoMClamped = clamp(VoM, 0.0, 1.0);
	float spaceFactor = min(max(cameraPosition.y, 0.0) / KARMAN_LINE, 1.0);
	//3.7 moon visibility saturates at the horizon (moon up = 1.0): moonlight lights up the nebula
	//with a pale blue glow, matching the 3.7 look even when the nebula runs on its own.
	float nebulaMoonVis = clamp(dot(-sunVec, upVec) + 0.0625, 0.0, 0.125) / 0.125;
	vec2 nebulaPlaneCoord = worldPos.xz / (length(worldPos.y) + length(vec3(worldPos.x, worldPos.y, worldPos.z)));
	        nebulaPlaneCoord += frameTimeCounter * 0.001;
	        nebulaPlaneCoord += cameraPosition.xz * 0.00001;
	float nebulaHeightFactor = max(1.0 - sqrt(nWorldPos.y), 0.0);
	//3.7 generated night nebula samples the independent 3.7 noise (noise3_7)
	float baseOctave = texture2D(noise3_7, nebulaPlaneCoord * 0.125).g;
	        baseOctave = max(baseOctave - 0.2, 0.0);
	float midOctave = texture2D(noise3_7, nebulaPlaneCoord * 0.25).r;
	        midOctave = max(midOctave - 0.175, nebulaHeightFactor * 0.25);
	float detailOctave = texture2D(noise3_7, nebulaPlaneCoord).r;
	        detailOctave = max(detailOctave - 0.075, nebulaHeightFactor * 0.25);
	float nebulaNoise = (0.25 + 0.75 * baseOctave) * midOctave * (0.25 + 0.75 * detailOctave) * 6.0;
	vec3 nebulaColor = vec3(0.3, 0.5 + midOctave * midOctave * midOctave * 3.0, 1.0);
	        nebulaNoise = max(nebulaNoise * nWorldPos.y * pow(1.0 - nWorldPos.y, 1.5 - VoMClamped * 0.5), 0.0);
	float nebulaVis = (0.5 + VoMClamped * 0.5) * (1.0 - nebulaHeightFactor) * (nebulaNoise + pow3(nebulaNoise) * 9.0) * nebulaMoonVis * (1.0 - wetness) * (1.0 - pow(spaceFactor, 0.25)) * caveFactor;
	vec3 nebula = nebulaColor * nebulaVis;
	color.rgb += GENERATED_NIGHT_NEBULA_BRIGHTNESS * nebula * (1.0 - auroraOcclusion);
}
#endif

void drawMilkyWay(inout vec3 color, in vec3 worldPos, in float VoU, in float caveFactor, inout float nebulaFactor, in float volumetricClouds, in float auroraOcclusion) {
	#ifdef GENERATED_NIGHT_NEBULA
	drawGeneratedNightNebula(color, worldPos, caveFactor, auroraOcclusion);
	#endif

	#if defined SKY_3_7 || defined MILKY_WAY_3_7
	//3.7 full milky way: different plane mapping, space-factor visibility and deep-space tint.
	//The moon lights up the milky way (pow4 of moon visibility), so it is brightest under a full moon.
	//The 3.7 moon visibility saturates right at the horizon (moon up = 1.0) so the band stays evenly
	//bright across the sky (including the zenith), which keeps the moon/milky-way interaction visible.
	//This keeps the milky way continuous with the 3.7 sky (no visible seam at the horizon).
	float spaceFactor = min(max(cameraPosition.y, 0.0) / KARMAN_LINE, 1.0);
	float VoUFactor = mix(sqrt(max(VoU, 0.0)), VoU * 0.5 + 0.5, spaceFactor);
	float nebulaMoonVis = clamp(dot(-sunVec, upVec) + 0.0625, 0.0, 0.125) / 0.125;
	//rainStrength is not available in the water reflection programs, use wetness there
	#ifdef GBUFFERS_WATER
	float milkyRain = wetness;
	#else
	float milkyRain = rainStrength;
	#endif
	float visibility = mix(pow4(nebulaMoonVis) * (1.0 - milkyRain), 1.0, spaceFactor) * VoUFactor * MILKY_WAY_BRIGHTNESS * caveFactor;

	if (visibility > 0.1) {
		vec2 planeCoord = worldPos.zx / (length(worldPos.y) + length(worldPos.zyx));
		        planeCoord += frameTimeCounter * 0.0001;
		        planeCoord *= 0.75;
		        planeCoord.x *= 2.0;
		        planeCoord.x -= 0.2;
		        planeCoord.y -= 0.7;

		#ifdef DEFERRED
		vec4 milkyWay = texture2D(depthtex2, planeCoord * 0.5 + 0.6);
		#else
		vec4 milkyWay = texture2D(gaux4, planeCoord * 0.5 + 0.6);
		#endif
		milkyWay.rgb = fmix(lightNight * 1.75, vec3(0.25), 0.5 + spaceFactor * 0.25) * milkyWay.rgb * pow(milkyWay.a, 6.0 - spaceFactor * 3.0) * length(milkyWay.rgb) * visibility;
		nebulaFactor = length(milkyWay.rgb) * (5.0 - spaceFactor * 3.0);
	#ifdef GBUFFERS_WATER
		milkyWay.rgb *= 3.0; //brightness compensation for water reflections
	#endif
		color += milkyWay.rgb * (1.0 - auroraOcclusion);
	}
	#else
	float visibility = (1.0 - timeBrightnessSqrt) * (1.0 - wetness) * (1.0 - volumetricClouds) * sqrt(max(VoU, 0.0)) * MILKY_WAY_BRIGHTNESS * caveFactor;

	if (visibility > 0.0) {
		vec2 planeCoord = worldPos.zx / (worldPos.y + length(worldPos.zyx));
			 planeCoord += frameTimeCounter * 0.001;
			 planeCoord *= 0.8;
			 planeCoord.x *= 1.9;
		
		vec4 milkyWay = texture2D(depthtex2, planeCoord * 0.5 + 0.6);
		color += mix(lightNight, vec3(1.0), 0.25) * milkyWay.rgb * pow6(milkyWay.a) * length(milkyWay.rgb) * visibility * (1.0 - auroraOcclusion);
		nebulaFactor = length(milkyWay.rgb);
	}
	#endif
}
#endif

#ifdef END_NEBULA
float getSpiralWarping(vec2 coord){
	float whirl = END_VORTEX_WHIRL;
	float arms = END_VORTEX_ARMS;
	float spiralRot = frameTimeCounter * 0.125;
	#ifdef PORT_END_ON
	//Rotation is already carried by the revolving plane coords - keep the nebula locked to the black hole
	spiralRot = 0.0;
	#endif

    coord = vec2(atan(coord.y, coord.x) - spiralRot, sqrt(coord.x * coord.x + coord.y * coord.y));
    float center = pow8(1.0 - coord.y) * 24.0;
    float spiral = sin((coord.x + sqrt(coord.y) * whirl) * arms) + center - coord.y;

    return clamp(spiral * 0.1, 0.0, 1.0);
}

void getEndNebula(inout vec3 color, in vec3 worldPos, in float VoU, inout float nebulaFactor, in float caveFactor) {
	float visibility = pow2(1.0 - abs(VoU)) * END_NEBULA_BRIGHTNESS;

	if (visibility > 0.0) {
		//The revolving black hole direction is already baked into sunVec by getSunVector (VSH) - rotate only once, never here
		vec3 sunVec = mat3(gbufferModelViewInverse) * sunVec;
		vec2 sunCoord = sunVec.xz / (sunVec.y + length(sunVec));
		vec2 planeCoord1 = worldPos.xz / (length(worldPos) + worldPos.y) - sunCoord;
		vec2 planeCoord2 = worldPos.xz / length(worldPos) - sunCoord;
		//Original wide, soft background glow restored - the plane coords already pivot around the black hole
		//centre, so the nebula still follows the revolving hole without being dimmed into a tight core.
		float bhGlow = 1.0;
		float spiral1 = getSpiralWarping(planeCoord1) * clamp(VoU, 0.0, 1.0);
		float spiral2 = getSpiralWarping(planeCoord2) * clamp(VoU, 0.0, 1.0);
			 planeCoord1 += cameraPosition.xz * 0.0001;
			 planeCoord2 += cameraPosition.xz * 0.0001;
			 planeCoord1 += spiral1;
			 planeCoord2 += spiral2 * 2.0;

		float nebulaNoise1  = texture2D(noisetex, planeCoord1 * 0.01 + frameTimeCounter * 0.0001).r;
			  nebulaNoise1 += texture2D(noisetex, planeCoord1 * 0.02 - frameTimeCounter * 0.0002).r * 0.500;
			  nebulaNoise1 += texture2D(noisetex, planeCoord1 * 0.04 + frameTimeCounter * 0.0003).r * 0.250;
			  nebulaNoise1 += texture2D(noisetex, planeCoord1 * 0.08 - frameTimeCounter * 0.0004).r * 0.250;
			  nebulaNoise1 += texture2D(noisetex, planeCoord1 * 0.16 + frameTimeCounter * 0.0005).r * 0.125;
			  nebulaNoise1 = clamp(nebulaNoise1 - 0.7, 0.0, 1.0);
		float nebulaNoise2  = texture2D(noisetex, planeCoord2 * 0.02 - frameTimeCounter * 0.00015).r;
			  nebulaNoise2 += texture2D(noisetex, planeCoord2 * 0.04 + frameTimeCounter * 0.00030).r * 0.75;
			  nebulaNoise2 += texture2D(noisetex, planeCoord2 * 0.08 - frameTimeCounter * 0.00060).r * 0.50;
			  nebulaNoise2 = clamp(nebulaNoise2 - 0.8, 0.0, 1.0);

		color += mix(mix(endAmbientCol, endLightCol, nebulaNoise1), mix(vec3(2.0, 0.8, 0.2), vec3(0.1, 2.1, 0.8), nebulaNoise1), texture2D(noisetex, planeCoord1 * 0.025).r * 0.4) * visibility * nebulaNoise1 * bhGlow;
		color += mix(vec3(2.3, 0.8, 0.5), vec3(1.2, 2.2, 0.9), nebulaNoise2 - 0.25) * visibility * pow2(nebulaNoise2) * 0.125 * bhGlow;
		nebulaFactor = (nebulaNoise1 + nebulaNoise2) * visibility;
	}
}
#endif

#ifdef END_VORTEX
vec3 getSpiral(vec2 coord, float hole) {
	float whirl = END_VORTEX_WHIRL * mix(1.0, 3.0, pow4(hole));
	float arms = END_VORTEX_ARMS;
	float spiralRot = frameTimeCounter * 0.125;
	#ifdef PORT_END_ON
	//Rotation is already carried by the revolving plane coords - keep the vortex locked to the black hole
	spiralRot = 0.0;
	#endif

    coord = vec2(atan(coord.y, coord.x) - spiralRot, sqrt(coord.x * coord.x + coord.y * coord.y));
    float center = pow8(1.0 - coord.y) * 24.0;
    float spiral = sin((coord.x + sqrt(coord.y) * whirl) * arms) + center - coord.y;

    return clamp(endAmbientColSqrt * spiral * 0.15, 0.0, 1.0);
}

void getEndVortex(inout vec3 color, in vec3 worldPos, in vec3 stars, in float VoU, in float VoS) {
	#ifdef PORT_END_ON
	//Wide visibility range so the black hole stays visible across the sky while revolving (no hard clip)
	if (VoS > 0.05) {
	#else
	//Vanilla: original visibility threshold untouched
	if (VoS > 0.5) {
	#endif
		//The revolving black hole direction is already baked into sunVec by getSunVector (VSH) - rotate only once, never here
		vec3 sunVec = mat3(gbufferModelViewInverse) * sunVec;
		vec2 sunCoord = sunVec.xz / (sunVec.y + length(sunVec));
		vec2 dirProj = worldPos.xz / (worldPos.y + length(worldPos));
		#ifdef PORT_END_ON
		//All components share the black-hole-centred frame (dirProj - sunCoord) so they stay perfectly aligned
		vec2 planeCoord0 = dirProj - sunCoord;
		vec2 planeCoord1 = dirProj - sunCoord;
		vec2 center = vec2(0.0);
		#else
		vec2 planeCoord0 = dirProj + sunCoord;
			 planeCoord0.x += 0.5;
			 planeCoord0.y -= 0.23;
		vec2 planeCoord1 = dirProj - sunCoord;
		vec2 center = vec2(0.5);
		#endif
		
		float dist = distance(planeCoord0, center);
		float invDist = 1.0 - dist;
		#ifdef PORT_END_ON
		//Fade out smoothly near the screen edge instead of hard-clipping the black hole
		float edgeFade = smoothstep(1.0, 0.6, dist);
		#else
		float edgeFade = 1.0;
		#endif
		float ring = pow(smoothstep(0.3, 0.05, dist * 1.5) * 4.0, 3.5) + 1.0;

		float hole = step(0.05, dist);
			  hole *= smoothstep(0.085, 0.100, dist);

		#ifdef PORT_END_ON
		vec3 accretionDisk = endLightCol * pow7(max(invDist, 0.0)) * 0.25;
		#else
		vec3 accretionDisk = endLightCol * pow7(invDist) * 0.25;
		#endif
		vec3 spiral = getSpiral(planeCoord1, VoS);
		#ifdef PORT_END_ON
		//Hide the vortex inside the event horizon so it cannot leak through the black core
		spiral *= smoothstep(0.05, 0.12, dist);
		#endif

		color = mix(color, spiral, pow3(length(spiral)));
		color += clamp(ring * hole * accretionDisk * edgeFade, 0.0, 1.0);
		#ifdef PORT_END_ON
		//Event horizon: black core responds to the glow black-level control (lifts from pure black)
		color *= mix(1.0, ENH_END_GLOW_BLACK_LEVEL, 1.0 - hole);
		//Wide soft glow on top of the black hole - radius/contrast/brightness/black-level all tuneable
		vec3 glowCol = mix(vec3(dot(endLightCol, vec3(0.3333))), endLightCol, ENH_END_GLOW_SATURATION);
		float glowDist = dist / ENH_END_GLOW_RADIUS;
		color += glowCol * (pow(max(1.0 - glowDist, 0.0), ENH_END_GLOW_CONTRAST) * 0.28 * ENH_END_GLOW_BRIGHTNESS * smoothstep(0.05, 0.12, dist) + ENH_END_GLOW_BLACK_LEVEL) * edgeFade;
		#ifdef PORT_END_LENS_ON
		//Visible gravitational vortex: swept star streaks around the black hole
		vec2 swirlP = planeCoord0;
		float sr = length(swirlP);
		float sa = atan(swirlP.y, swirlP.x);
		float swirlStreng = ENH_END_LENS_STRENGTH * exp(-sr * 2.0);
		float streak = pow(max(sin(sa * 7.0 + sr * 10.0 + swirlStreng * 4.0), 0.0), 3.0);
		float swirlMask = exp(-sr * 2.5) * smoothstep(0.6, 0.2, sr);
		color += endLightCol * streak * swirlMask * 0.35 * ENH_END_LENS_STRENGTH * edgeFade;
		#endif
		#else
		//Vanilla: original mask untouched
		color *= mix(1.0, 0.0, float(VoS > 0.97) * (1.0 - hole));
		#endif
	}
}
#endif

#ifdef AURORA
float getAuroraNoise(vec2 coord) {
	float noise = texture2D(noisetex, coord * 0.0050 + frameTimeCounter * 0.00004).b * 3.0;
		  noise+= texture2D(noisetex, coord * 0.0025 - frameTimeCounter * 0.00008).b * 3.0;

	return max(1.0 - 2.0 * abs(noise - 3.0), 0.0);
}

void drawAurora(inout vec3 color, in vec3 worldPos, in float VoU, in float caveFactor, in float volumetricClouds) {
	float visibilityMultiplier = pow6(1.0 - sunVisibility) * (1.0 - wetness) * (1.0 - volumetricClouds) * caveFactor * AURORA_BRIGHTNESS;
	float visibility = 0.0;

	#ifdef OVERWORLD
	#ifdef AURORA_FULL_MOON_VISIBILITY
	visibility = mix(visibility, 1.0, float(moonPhase == 0));
	#endif

	#ifdef AURORA_COLD_BIOME_VISIBILITY
	visibility = mix(visibility, 1.0, isSnowy);
	#endif
	#endif

    #ifdef AURORA_ALWAYS_VISIBLE
    visibility = 1.0;
    #endif

	visibility *= visibilityMultiplier;

	if (visibility > 0.0) {
		vec3 aurora = vec3(0.0);

        float dither = Bayer8(gl_FragCoord.xy);

        #ifdef TAA
        dither = fract(frameTimeCounter * 16.0 + dither);
        #endif

		int samples = 16;
		float sampleStep = 1.0 / samples;
		float currentStep = dither * sampleStep;

		float pulse = sin(frameTimeCounter);

		for (int i = 0; i < samples; i++) {
			vec3 planeCoord = worldPos * ((14.0 + currentStep * 14.0 - clamp(cameraPosition.y * 0.001, 0.0, 9.0)) / worldPos.y) * 0.025;
				 planeCoord.xy *= 0.75;
			vec2 offsetNoiseCoord = planeCoord.xz + cameraPosition.xz * 0.00005;
				 planeCoord *= 0.5 + texture2D(noisetex, (offsetNoiseCoord + frameTimeCounter * 0.0001) * 0.05).r * 0.5;
			vec2 coord = planeCoord.xz + cameraPosition.xz * 0.0001;

			float noise = getAuroraNoise(coord + frameTimeCounter * 0.0008);
			float noiseBase = noise;
			
			if (noise > 0.0) {
				float auroraDistanceFactor = max(1.0 - length(planeCoord.xz) * 0.25, 0.0);

				noise *= texture2D(noisetex, coord * 0.125 + frameTimeCounter * 0.0008).b * (0.4 - pulse * 0.1) + (0.6 + pulse * 0.1);
				noise *= texture2D(noisetex, coord * 0.250 - frameTimeCounter * 0.0010).b * (0.5 - pulse * 0.2) + (0.5 + pulse * 0.2);
				noise *= noise * sampleStep * auroraDistanceFactor;
				noiseBase *= sampleStep * auroraDistanceFactor;

				float colorMixer = clamp(texture2D(noisetex, coord * 0.0025).b * 1.5, 0.0, 1.0);

				vec3 auroraColor1 = mix(vec3(0.6, 4.0, 0.4), vec3(3.4, 0.1, 1.5), pow(currentStep, 0.25));
					 auroraColor1 *= exp2(-3.0 * i * sampleStep);
				vec3 auroraColor2 = mix(vec3(0.3, 4.0, 0.7), vec3(1.9, 0.4, 3.7), pow(currentStep, 0.50));
					 auroraColor2 *= exp2(-4.5 * i * sampleStep);

				vec3 auroraColor = mix(auroraColor1, auroraColor2, pow3(colorMixer));
				vec3 auroraBlurredColor = auroraColor * noiseBase;
					 auroraColor *= noise;
					 auroraColor *= 1.0 + length(auroraColor);
				aurora += (auroraBlurredColor * (0.4 - pulse * 0.2) + auroraColor * (0.7 + pulse * 0.3));
			}

			currentStep += sampleStep;
		}

		color += aurora * visibility * (1.0 - clamp(pow(VoU, 0.6), 0.0, 0.7));
	}
}
#endif

#ifdef PLANAR_CLOUDS
float samplePlanarCloudNoise(in vec2 coord) {
    float noise = texture2D(noisetex, coord * 0.0625).r * 15.0;
          noise = mix(noise, texture2D(noisetex, coord).r * 2.0, 0.33);
          noise = max(noise - 6.0, 0.0);
          noise /= sqrt(noise * noise + 0.25);
          noise = clamp(noise, 0.0, 1.0);
    return noise;
}

void drawPlanarClouds(inout vec3 color, in vec3 atmosphereColor, in vec3 worldPos, in vec3 viewPos, in float VoU, in float caveFactor, in float volumetricClouds, inout float pc) {
    vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

    float VoL = clamp(dot(normalize(viewPos), lightVec), 0.0, 1.0) * shadowFade;
    float cloudHeightFactor = pow2(max(1.0 - 0.00025 * cameraPosition.y, 0.0));

    //Sampling
	vec3 planeCoord = worldPos * (cloudHeightFactor / worldPos.y) * 0.2;
         planeCoord.x *= 2.00;
         planeCoord.z *= 0.75;
	vec2 coord = cameraPosition.xz * 0.0001 + planeCoord.xz + frameTimeCounter * 0.001;

    float noise = samplePlanarCloudNoise(coord);
    float lightingNoise = samplePlanarCloudNoise(coord + normalize(ToWorld(lightVec * 10000.0)).xy * 0.1);

    //Lighting and coloring
	#if defined AURORA && defined AURORA_3_7
	//3.7 aurora on planar clouds (kpIndex geomagnetic activity)
	float kpIndex = abs(worldDay % 9 - worldDay % 4);
	      kpIndex = kpIndex - int(kpIndex == 1) + int(kpIndex > 7 && worldDay % 10 == 0);
	      kpIndex = min(max(kpIndex, 0) + isSnowy * 3, 9);
	#ifdef AURORA_ALWAYS_VISIBLE
	      kpIndex = 7;
	#endif
	float moonVisibility = clamp((dot(-sunVec, upVec) + 0.1) * 4.0, 0.0, 1.0);
	float auroraVisibility = pow6(moonVisibility) * (1.0 - wetness) * caveFactor;
	float pulse = 0.5 + 0.5 * sin(frameTimeCounter * 0.08 + sin(frameTimeCounter * 0.013) * 0.6);
	      pulse = smoothstep(0.15, 0.85, pulse);
	float longPulse = sin(frameTimeCounter * 0.025 + sin(frameTimeCounter * 0.004) * 0.8);
	      longPulse = longPulse * (1.0 - 0.15 * abs(longPulse));
	kpIndex *= 1.0 + longPulse * 0.25;
	kpIndex /= 9.0;
	float redPhase = pow3(kpIndex) * (1.0 - pulse);
	vec3 nWorldPos = normalize(worldPos);
	float westEast = clamp(1.0 - abs(nWorldPos.x * 0.05) + kpIndex * kpIndex, 0.0, 1.0);
	float north = clamp(10.0 * kpIndex * kpIndex * kpIndex - nWorldPos.z, 0.0, 1.0);
	float auroraDistanceFactor = clamp(1.0 - length(nWorldPos.xz) * 0.02, 0.0, 1.0);
	auroraVisibility *= kpIndex * (1.0 + max(longPulse * 0.5, 0.0));
	auroraVisibility = min(auroraVisibility, 2.0) * AURORA_BRIGHTNESS;
	auroraVisibility *= auroraDistanceFactor * auroraDistanceFactor * north * westEast;
	float colorMixer = 0.65 + pow3(kpIndex) * pulse * 0.1;
	vec3 lowColor = vec3(0.45, 1.55 - redPhase * 0.5, 0.0);
	vec3 upColor = vec3(0.95 + redPhase * 5.0, 0.10, 0.0);
	vec3 auroraColor = fmix(lowColor, upColor, colorMixer);
	#elif defined AURORA
	float visibilityMultiplier = pow8(1.0 - sunVisibility) * (1.0 - wetness) * caveFactor * AURORA_BRIGHTNESS;
	float auroraVisibility = 0.0;

	#ifdef AURORA_FULL_MOON_VISIBILITY
	auroraVisibility = mix(auroraVisibility, 1.0, float(moonPhase == 0));
	#endif

	#ifdef AURORA_COLD_BIOME_VISIBILITY
	auroraVisibility = mix(auroraVisibility, 1.0, isSnowy);
	#endif

	#ifdef AURORA_ALWAYS_VISIBLE
	auroraVisibility = 1.0;
	#endif

	auroraVisibility *= visibilityMultiplier;
	#endif

	pc = noise * VoU * pow(length(planeCoord.y), 0.125) * (1.0 - wetness) * (1.0 - volumetricClouds) * caveFactor;

    float noiseDifference = noise - lightingNoise;
    float morningEveningFactor = mix(1.0, 0.66, sqrt(sunVisibility) * (1.0 - timeBrightnessSqrt));
	float cloudLighting = min(mix(noise * noise, lightingNoise, 0.25), 1.0);

	vec3 cloudAmbientColor = mix(ambientCol, atmosphereColor * atmosphereColor, 0.5 * sunVisibility);
         cloudAmbientColor *= 0.25 + sunVisibility * sunVisibility * (0.2 - wetness * 0.2);
	vec3 cloudLightColor = mix(lightCol, mix(lightCol, atmosphereColor, 0.5 * sunVisibility) * atmosphereColor * 2.0, sunVisibility * (1.0 - timeBrightness * 0.33));
         cloudLightColor *= morningEveningFactor * (2.0 + pow8(VoL) * 4.0);

	#if defined AURORA && defined AURORA_3_7 && defined AURORA_LIGHTING_INFLUENCE
	//3.7: aurora tints the cloud lighting in linear space, scaled for the 2.3 exposure
	cloudLightColor *= 1.0 + auroraColor * auroraVisibility * 2.6;
	cloudLightColor /= 1.0 + auroraVisibility * 1.3;
	#endif

    vec3 cloudColor = mix(cloudLightColor, cloudAmbientColor, cloudLighting);
         cloudColor = pow(cloudColor, vec3(1.0 / 2.2));
		 #if defined AURORA && !defined AURORA_3_7
		 cloudColor = mix(cloudColor, vec3(0.4, 2.5, 0.9) * auroraVisibility, auroraVisibility * 0.05);
		 #endif

    color = mix(color, cloudColor * PLANAR_CLOUDS_BRIGHTNESS, pc * PLANAR_CLOUDS_OPACITY);
}
#endif

#ifdef RAINBOW
void getRainbow(inout vec3 color, in vec3 worldPos, in float VoU, in float size, in float radius, in float caveFactor) {
	float visibility = sunVisibility * (1.0 - rainStrength) * (1.0 - isSnowy) * wetness * max(VoU, 0.0) * caveFactor * RAINBOW_BRIGHTNESS;

	if (visibility > 0.0) {
		vec2 planeCoord = worldPos.xy / (worldPos.y + length(worldPos.xz) * 0.65);
		vec2 rainbowCoord = vec2(planeCoord.x + 2.5, planeCoord.y);

		float rainbowFactor = clamp(1.0 - length(rainbowCoord) / size, 0.0, 1.0);
		
		vec3 rainbow = 
			(smoothstep(0.0, radius, rainbowFactor) - smoothstep(radius, radius * 2.0, rainbowFactor)) * vec3(0.5, 0.0, 0.0) +
			(smoothstep(radius * 0.5, radius * 1.5, rainbowFactor) - smoothstep(radius * 1.5, radius * 2.5, rainbowFactor)) * vec3(0.0, 0.5, 0.0) +
			(smoothstep(radius, radius * 2.0, rainbowFactor) - smoothstep(radius * 2.0, radius * 3.0, rainbowFactor)) * vec3(0.0, 0.0, 0.5)
		;

		color += rainbow * visibility;
	}
}
#endif