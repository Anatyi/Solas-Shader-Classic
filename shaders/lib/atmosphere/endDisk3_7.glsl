//End Disk 3.7 (Ender Protoplanetary Disk / 末地云雾), ported from Solas Shader 3.7.
//Independent control END_DISK_3_7 (default off). Included from deferred2.glsl.
//Dependencies: ToView/ToWorld/ToShadow, texture2DShadow, noisetex, endLightCol, sunVec, upVec,
//cameraPosition, frameTimeCounter, blindFactor, darknessFactor(1.19+), shadowtex1, shadowDistance.

#ifndef TEXTURE2D_SHADOW_DEFINED
#define TEXTURE2D_SHADOW_DEFINED
float texture2DShadow(sampler2D shadowtex, vec3 shadowPos) {
    float shadow = texture2D(shadowtex, shadowPos.xy).r;
    return clamp((shadow - shadowPos.z) * 65536.0, 0.0, 1.0);
}
#endif

float getProtoplanetaryDisk3_7(vec2 coord) {
	float whirl = -5;
	float arms = 5;

    coord = vec2(atan(coord.y, coord.x) + frameTimeCounter * 0.01, sqrt(coord.x * coord.x + coord.y * coord.y));
    float center = pow4(1.0 - coord.y) * 1.0;
    float spiral = sin((coord.x + sqrt(coord.y) * whirl) * arms) + center - coord.y;

    return spiral;
}

void getEndCloudSample3_7(vec2 rayPos, vec2 wind, float attenuation, inout float noise) {
	rayPos *= 0.00025;

	float worleyNoise = (1.0 - texture2D(noisetex, rayPos.xy + wind * 0.5).g) * 0.5 + 0.25;
	float perlinNoise = texture2D(noisetex, rayPos.xy + wind * 0.5).r;
	float noiseBase = perlinNoise * 0.5 + worleyNoise * 0.5;

	float detailZ = floor(attenuation * END_DISK_THICKNESS_3_7) * 0.05;
	float noiseDetailA = texture2D(noisetex, rayPos - wind + detailZ).b;
	float noiseDetailB = texture2D(noisetex, rayPos - wind + detailZ + 0.05).b;
	float noiseDetail = mix(noiseDetailA, noiseDetailB, fract(attenuation * END_DISK_THICKNESS_3_7));

	float noiseCoverage = abs(attenuation - 0.125) * (attenuation > 0.125 ? 1.14 : 7.0);
		     noiseCoverage *= noiseCoverage * 7.0;

	noise = mix(noiseBase, noiseDetail, 0.025 * int(0 < noiseBase)) * 22.0 - noiseCoverage;
	noise = max(noise - END_DISK_AMOUNT_3_7 - 1.0 + getProtoplanetaryDisk3_7(rayPos) * 2.0, 0.0);
	noise /= sqrt(noise * noise + 0.25);
}

void computeEndDisk3_7(inout vec4 vc, in vec3 atmosphereColor, float z, float dither, inout float currentDepth) {
	//Total visibility
	float visibility = int(0.56 < z);

	#if MC_VERSION >= 11900
	visibility *= 1.0 - darknessFactor;
	#endif

	visibility *= 1.0 - blindFactor;

	if (visibility > 0.0) {
		//Positions
		vec3 viewPos = ToView(vec3(texCoord, z));
		vec3 nViewPos = normalize(viewPos);
        vec3 worldPos = ToWorld(viewPos);

		float VoU = dot(nViewPos, upVec);
		float VoS = clamp(dot(nViewPos, sunVec), 0.0, 1.0);
		vec3 nWorldPos = normalize(worldPos);

        float blackHoleDistortion = 0.0;
		#ifdef END_TIME_TILT
			float time = min(0.025 * frameTimeCounter, 1.0);
			nWorldPos.y += nWorldPos.x * time;
			blackHoleDistortion *= time;
		#endif
        nWorldPos.y += nWorldPos.x * END_ANGLE_3_7;
        nWorldPos.y -= blackHoleDistortion;
        #ifdef END_67
        if (frameCounter < 500) {
            nWorldPos.y += nWorldPos.x * 0.5 * sin(frameTimeCounter * 8);
        }
        #endif

		#if defined DISTANT_HORIZONS
		float dhZ = texture2D(dhDepthTex0, texCoord).r;
		vec4 dhScreenPos = vec4(texCoord, dhZ, 1.0);
		vec4 dhViewPos = dhProjectionInverse * (dhScreenPos * 2.0 - 1.0);
			 dhViewPos /= dhViewPos.w;
		float lDhViewPos = length(dhViewPos.xyz);
		#endif

		//Setting the ray marcher
		float cloudTop = END_DISK_HEIGHT_3_7 + (END_DISK_THICKNESS_3_7 + blackHoleDistortion * 5.0) * 10.0;
		float lowerPlane = (END_DISK_HEIGHT_3_7 - cameraPosition.y) / nWorldPos.y;
		float upperPlane = (cloudTop - cameraPosition.y) / nWorldPos.y;
		float minDist = max(min(lowerPlane, upperPlane), 0.0);
		float maxDist = max(lowerPlane, upperPlane);

		float planeDifference = maxDist - minDist;
		float rayLength = (END_DISK_THICKNESS_3_7 + blackHoleDistortion * 5.0) * 6.0;
			    rayLength /= nWorldPos.y * nWorldPos.y * 6.0 + 1.0;
		vec3 startPos = cameraPosition + minDist * nWorldPos;
		vec3 sampleStep = nWorldPos * rayLength;
		int sampleCount = int(min(planeDifference / rayLength, 64) + dither);

		if (maxDist >= 0.0 && sampleCount > 0) {
			float cloud = 0.0;
			float cloudAlpha = 0.0;
			float cloudLighting = 0.0;

			//Scattering variables
			float halfVoLSqrt = VoS * 0.5 + 0.5;
			float halfVoL = halfVoLSqrt * halfVoLSqrt;
			float scattering = pow8(halfVoLSqrt);

            vec3 worldLightVec = normalize(ToWorld(sunVec * 100000000.0));
                    worldLightVec.xz *= 32.0;

			vec3 rayPos = startPos + sampleStep * dither;

			float maxDepth = currentDepth;
			float minimalNoise = 0.25 + dither * 0.25;
			float sampleTotalLength = minDist + rayLength * dither;

			vec2 wind = vec2(frameTimeCounter * 0.005, sin(frameTimeCounter * 0.1) * 0.01) * 0.1;

			//Fade distance (3.7 control). 0 = auto: 2000 when the vanilla End nebula is on, else
			//4000 (the 3.7 default). Any other value overrides the fade distance directly.
			#ifdef END_NEBULA
			float endDiskFadeDist = END_DISK_FADE_DISTANCE_3_7 > 0.0 ? END_DISK_FADE_DISTANCE_3_7 : 2000.0;
			#else
			float endDiskFadeDist = END_DISK_FADE_DISTANCE_3_7 > 0.0 ? END_DISK_FADE_DISTANCE_3_7 : 4000.0;
			#endif

			//Ray marcher
			for (int i = 0; i < sampleCount; i++, rayPos += sampleStep, sampleTotalLength += rayLength) {
				if (0.99 < cloudAlpha || (length(viewPos) < sampleTotalLength && z < 1.0)) break;

				#if defined DISTANT_HORIZONS
				if ((lDhViewPos < sampleTotalLength && dhZ < 1.0)) break;
				#endif

                vec3 worldPos = rayPos - cameraPosition;

				float shadow1 = clamp(texture2DShadow(shadowtex1, ToShadow(worldPos)), 0.0, 1.0);

				float noise = 0.0;
				float lightingNoise = 0.0;
				float rayDistance = length(worldPos.xz) * 0.1;
				float attenuation = smoothstep(END_DISK_HEIGHT_3_7, cloudTop, rayPos.y);

                getEndCloudSample3_7(rayPos.xz, wind, attenuation, noise);
                getEndCloudSample3_7(rayPos.xz + worldLightVec.xz, wind, attenuation, lightingNoise);

				float powder = 1.0 - 0.925 * exp(-pow(noise, 1.0 + noise * 7.0));
				float directionalScattering = 1.0 - exp(-2.0 * (noise - lightingNoise * 0.9));
                float sampleLighting = clamp((0.125 + attenuation * 0.875) * powder * directionalScattering * 2.0, 0.0, 1.0);

                cloudLighting = fmix(cloudLighting, sampleLighting, noise * (1.0 - cloud * cloud));

				if (length(worldPos) < shadowDistance) cloudLighting *= 0.5 + shadow1 * 0.5;
				cloud = fmix(cloud, 1.0, noise);
				noise *= pow8(smoothstep(endDiskFadeDist, 8.0, rayDistance)); //Fog (3.7 fade distance control)
				cloudAlpha = fmix(cloudAlpha, 1.0, noise);

				//gbuffers_water/translucent cloud discard check - use the accumulated cloud alpha so
				//the ender disk reliably culls transparent geometry (glass) behind it.
				if (cloudAlpha > 0.05 && currentDepth == maxDepth) {
					currentDepth = sampleTotalLength;
				}
			}

			//Final color calculations - 2.3 End fog color/lighting (matches the vanilla End fog)
            vec3 cloudColor = mix(endAmbientCol * 0.2, endLightCol * 0.4, cloudLighting) * (1.0 + scattering * 3.0);

			vc = vec4(cloudColor, cloudAlpha * END_DISK_OPACITY_3_7) * visibility;
		}
	}
}
