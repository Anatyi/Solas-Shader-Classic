float getCloudNoise(vec2 pos, float amount) {
	const float roundness = 0.2;
	pos = pos * 0.05 + 0.5;
	vec2 a, b = modf(1.0 + abs(pos), a);
	b = smoothstep(0.5 - roundness, roundness + 0.5, b);
	vec2 cellUV = (a + b - 0.5) / 256.0;
	vec2 noiseCoord = sign(pos) * cellUV;

	//Cloud-block shape from the sparse clouds.png mask
	float shape = float(texture2D(shadowcolor1, noiseCoord).r > 0.0);

	//Coverage gate (value noise, coherent per 4x4-cell block)
	vec2 cellCoord = sign(pos) * (floor(a * 0.25) - 0.5) / 64.0;
	float coverage = texture2D(noisetex, cellCoord).r;

	//AMOUNT < 1.0: drop a fraction of the blobs -> fewer clouds
	if (amount < 1.0) {
		return shape * float(coverage > (1.0 - amount) * 0.9);
	}

	//AMOUNT > 1.0: keep the full base mask and add shifted blob copies -> more clouds
	//Each copy fades in over one amount step (up to amount 5.0)
	float extra = clamp(amount - 1.0, 0.0, 4.0);

	float extraShape = float(texture2D(shadowcolor1, sign(pos) * (cellUV + vec2(0.50, 0.00))).r > 0.0);
	shape = max(shape, extraShape * float(coverage > (1.0 - clamp(extra, 0.0, 1.0)) * 0.9));
	extraShape = float(texture2D(shadowcolor1, sign(pos) * (cellUV + vec2(0.00, 0.50))).r > 0.0);
	shape = max(shape, extraShape * float(coverage > (1.0 - clamp(extra - 1.0, 0.0, 1.0)) * 0.9));
	extraShape = float(texture2D(shadowcolor1, sign(pos) * (cellUV + vec2(0.25, 0.50))).r > 0.0);
	shape = max(shape, extraShape * float(coverage > (1.0 - clamp(extra - 2.0, 0.0, 1.0)) * 0.9));
	extraShape = float(texture2D(shadowcolor1, sign(pos) * (cellUV + vec2(0.75, 0.25))).r > 0.0);
	shape = max(shape, extraShape * float(coverage > (1.0 - clamp(extra - 3.0, 0.0, 1.0)) * 0.9));

	return shape;
}

float texture2DShadow(sampler2D shadowtex, vec3 shadowPos) {
    float shadow = texture2D(shadowtex, shadowPos.xy).r;

    return clamp((shadow - shadowPos.z) * 65536.0, 0.0, 1.0);
}

//Renders one blocky cloud layer with ray marching. Layers are called in ray-depth order
//(nearer first) so cloud layers cull each other correctly without affecting depth to ground/water.
void renderCloudLayer(inout vec4 vc, inout float cloudDepth,
    in vec3 nWorldPos, in float lViewPos, in float lViewPosFar,
    in float dither, in float distanceFactor,
    in vec3 cloudLightCol, in vec3 cloudAmbientCol, in float auroraVisibility,
    in float cloudHeight, in float cloudXZStretch, in float cloudThickness,
    in float cloudAmount, in float cloudBrightness, in float cloudOpacity,
    in vec2 cloudFlow, in vec2 cloudNoiseOffset) {

	float stretching = 8.0 * cloudThickness;
	float lowerPlane = (cloudHeight + stretching - cameraPosition.y) / nWorldPos.y;
	float upperPlane = (cloudHeight - stretching - cameraPosition.y) / nWorldPos.y;
	float minDist = max(min(lowerPlane, upperPlane), 0.0);
	float maxDist = min(max(lowerPlane, upperPlane), distanceFactor);
	float rayLength = maxDist - minDist;

	float sampleTotalLength = minDist + rayLength * dither;

	int sampleCount = clamp(int(rayLength), 0, 16);

	if (sampleCount > 0) {
		vec3 rayPos = cameraPosition + nWorldPos * minDist;
		vec3 rayDir = nWorldPos * (rayLength / sampleCount);
		rayPos += rayDir * dither;
		rayPos.y -= rayDir.y;

		float cloudAlpha = 0.0;
		float maxDepth = cloudDepth;
		float minimalNoise = 0.25 + dither * 0.25;

		for (int i = 0; i < sampleCount; i++, sampleTotalLength += rayLength) {
			rayPos += rayDir;
			vec3 worldPos = rayPos - cameraPosition;

			float lWorldPos = length(worldPos);
			float lWorldPosXZ = length(worldPos.xz);

			if (cloudAlpha > 0.99 || lWorldPos > lViewPosFar || lWorldPosXZ > distanceFactor) break;

			float shadowSample = 1.0;
			float shadowLength = clamp(shadowDistance * 0.9166667 - length(worldPos.xz), 0.0, 1.0);

			#ifdef VC_SHADOWS
			shadowSample = texture2DShadow(shadowtex1, ToShadow(worldPos));
			#endif

			//Indoor leak prevention
			if (eyeBrightnessSmooth.y < 200.0 && shadowLength > 0.0) {
				#ifndef VC_SHADOWS
				shadowSample = texture2DShadow(shadowtex1, ToShadow(worldPos));
				#endif
				if (shadowSample == 0.0) break;
			}

			float cloudFog = 1.0 - clamp(lWorldPos * 0.00075, 0.0, 1.0);
			float noise = getCloudNoise(rayPos.xz / cloudXZStretch + cloudNoiseOffset + cloudFlow, cloudAmount);
			cloudAlpha = clamp(noise, 0.0, 1.0);

			//gbuffers_water cloud discard check
			if (noise > minimalNoise && cloudDepth == maxDepth) {
				cloudDepth = pow(sampleTotalLength, 0.5);
			}

			float cloudLighting = clamp(smoothstep(cloudHeight + stretching * noise, cloudHeight - stretching * noise, rayPos.y), 0.0, 1.0);

			vec4 cloudColor = vec4(mix(mix(cloudAmbientCol, cloudLightCol, shadowSample), cloudAmbientCol, cloudLighting), cloudAlpha);
				 #ifdef AURORA
				 cloudColor.rgb = mix(cloudColor.rgb, vec3(0.4, 2.5, 0.9) * auroraVisibility, 0.02 - cloudLighting * auroraVisibility * 0.02);
				 #endif
				 //Opacity affects both the cloud color (incl. its shadow/light volume) and its alpha
				 cloudColor.rgb *= cloudColor.a * cloudBrightness * cloudOpacity;
				 cloudColor.a *= cloudOpacity;

			//Culling mode: 0/1 standard front-to-back alpha blending; 2 full mutual culling
			//(the nearer layer completely occludes the farther one wherever they overlap)
			#if BLOCKY_CLOUDS_CULLING == 2
			vc += cloudColor * (1.0 - step(0.01, vc.a)) * cloudFog;
			#else
			vc += cloudColor * (1.0 - vc.a) * cloudFog;
			#endif
		}
	}
}

void computeVolumetricClouds(inout vec4 vc, in vec3 atmosphereColor, in float z1, in float dither, inout float cloudDepth) {
	//Total visibility of clouds
	float visibility = caveFactor * int(z1 > 0.56);

	#if MC_VERSION >= 11900
	visibility *= 1.0 - darknessFactor;
	#endif

	visibility *= 1.0 - blindFactor;

	if (visibility > 0.0) {
		//Positions & Variables
		vec3 viewPos = ToView(vec3(texCoord, z1));
		vec3 nWorldPos = normalize(ToWorld(viewPos));
		float distanceFactor = VC_DISTANCE;

		vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
		float VoL = clamp(dot(normalize(viewPos), lightVec), 0.0, 1.0) * shadowFade;
		float lViewPos = length(viewPos);
		float lViewPosFar = lViewPos < far ? lViewPos - 1.0 : 99999999.0;

		float auroraVisibility = 0.0;

		#ifdef AURORA
		float visibilityMultiplier = pow8(1.0 - sunVisibility) * (1.0 - wetness) * caveFactor * AURORA_BRIGHTNESS;

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

		//Blend colors with the sky
		float atmosphereMixer = 0.5 * sunVisibility * sunVisibility;
		vec3 cloudLightCol = mix(lightCol, atmosphereColor, atmosphereMixer) * (1.0 + pow8(VoL));
		vec3 cloudAmbientCol = mix(ambientCol, atmosphereColor * 0.5, atmosphereMixer);

		//Cloud layers are rendered in ray-depth order (nearer first) so the nearer layer
		//correctly culls the farther one between layers - ground/water depth is unaffected.
		{
			float cloudHeight1 = BLOCKY_CLOUDS1_HEIGHT;
			float cloudXZStretch1 = BLOCKY_CLOUDS1_XZSTRETCH;
			float cloudThickness1 = BLOCKY_CLOUDS1_THICKNESS;
			float cloudAmount1 = BLOCKY_CLOUDS1_AMOUNT;
			float cloudBrightness1 = BLOCKY_CLOUDS1_BRIGHTNESS;
			float cloudOpacity1 = BLOCKY_CLOUDS1_OPACITY;
			vec2 cloudFlow1 = vec2(BLOCKY_CLOUDS1_FLOW, BLOCKY_CLOUDS1_FLOW * 0.2) * frameTimeCounter;

			float stretch1 = 8.0 * cloudThickness1;
			float minDist1 = max(min((cloudHeight1 + stretch1 - cameraPosition.y) / nWorldPos.y, (cloudHeight1 - stretch1 - cameraPosition.y) / nWorldPos.y), 0.0);

			#ifdef BLOCKY_CLOUDS2
			float cloudHeight2 = BLOCKY_CLOUDS2_HEIGHT;
			float cloudXZStretch2 = BLOCKY_CLOUDS2_XZSTRETCH;
			float cloudThickness2 = BLOCKY_CLOUDS2_THICKNESS;
			float cloudAmount2 = BLOCKY_CLOUDS2_AMOUNT;
			float cloudBrightness2 = BLOCKY_CLOUDS2_BRIGHTNESS;
			float cloudOpacity2 = BLOCKY_CLOUDS2_OPACITY;
			vec2 cloudFlow2 = vec2(BLOCKY_CLOUDS2_FLOW, BLOCKY_CLOUDS2_FLOW * 0.2) * frameTimeCounter;
			vec2 cloudNoiseOffset2 = vec2(BLOCKY_CLOUDS2_OFFSET) * 20.0;

			float stretch2 = 8.0 * cloudThickness2;
			float minDist2 = max(min((cloudHeight2 + stretch2 - cameraPosition.y) / nWorldPos.y, (cloudHeight2 - stretch2 - cameraPosition.y) / nWorldPos.y), 0.0);

			#if BLOCKY_CLOUDS_CULLING == 0
			//No culling: fixed Layer1 -> Layer2 order (layers are independent)
			renderCloudLayer(vc, cloudDepth, nWorldPos, lViewPos, lViewPosFar, dither, distanceFactor, cloudLightCol, cloudAmbientCol, auroraVisibility, cloudHeight1, cloudXZStretch1, cloudThickness1, cloudAmount1, cloudBrightness1, cloudOpacity1, cloudFlow1, vec2(0.0));
			renderCloudLayer(vc, cloudDepth, nWorldPos, lViewPos, lViewPosFar, dither, distanceFactor, cloudLightCol, cloudAmbientCol, auroraVisibility, cloudHeight2, cloudXZStretch2, cloudThickness2, cloudAmount2, cloudBrightness2, cloudOpacity2, cloudFlow2, cloudNoiseOffset2);
			#else
			//Nearer layer renders first so it occludes the farther one
			if (minDist2 < minDist1) {
				renderCloudLayer(vc, cloudDepth, nWorldPos, lViewPos, lViewPosFar, dither, distanceFactor, cloudLightCol, cloudAmbientCol, auroraVisibility, cloudHeight2, cloudXZStretch2, cloudThickness2, cloudAmount2, cloudBrightness2, cloudOpacity2, cloudFlow2, cloudNoiseOffset2);
				renderCloudLayer(vc, cloudDepth, nWorldPos, lViewPos, lViewPosFar, dither, distanceFactor, cloudLightCol, cloudAmbientCol, auroraVisibility, cloudHeight1, cloudXZStretch1, cloudThickness1, cloudAmount1, cloudBrightness1, cloudOpacity1, cloudFlow1, vec2(0.0));
			} else {
				renderCloudLayer(vc, cloudDepth, nWorldPos, lViewPos, lViewPosFar, dither, distanceFactor, cloudLightCol, cloudAmbientCol, auroraVisibility, cloudHeight1, cloudXZStretch1, cloudThickness1, cloudAmount1, cloudBrightness1, cloudOpacity1, cloudFlow1, vec2(0.0));
				renderCloudLayer(vc, cloudDepth, nWorldPos, lViewPos, lViewPosFar, dither, distanceFactor, cloudLightCol, cloudAmbientCol, auroraVisibility, cloudHeight2, cloudXZStretch2, cloudThickness2, cloudAmount2, cloudBrightness2, cloudOpacity2, cloudFlow2, cloudNoiseOffset2);
			}
			#endif
			#else
			renderCloudLayer(vc, cloudDepth, nWorldPos, lViewPos, lViewPosFar, dither, distanceFactor, cloudLightCol, cloudAmbientCol, auroraVisibility, cloudHeight1, cloudXZStretch1, cloudThickness1, cloudAmount1, cloudBrightness1, cloudOpacity1, cloudFlow1, vec2(0.0));
			#endif
		}
	}
	vc *= visibility;
}