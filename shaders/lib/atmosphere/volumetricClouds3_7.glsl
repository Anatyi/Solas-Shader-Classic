//Volumetric Clouds 3.7 Style (ported from Solas Shader 3.7)
//Active only with VC_3_7 (default off, keeps the 2.3 clouds). Depends on:
//VC_SPEED/AMOUNT/THICKNESS/DENSITY/DETAIL/HEIGHT/SCALE/DISTANCE/OPACITY, VC_DYNAMIC_WEATHER,
//worldDay, timeAngle, moonVisibility, isSnowy, isPaleGarden(1.21+), skyColor, atmosphereColor,
//lightCol, biomeColor, isSpecificBiome, timeBrightnessSqrt, FOG_DENSITY, lightVec, shadowtex1.
#ifndef TEXTURE2D_SHADOW_DEFINED
#define TEXTURE2D_SHADOW_DEFINED
float texture2DShadow(sampler2D shadowtex, vec3 shadowPos) {
    float shadow = texture2D(shadowtex, shadowPos.xy).r;

    return clamp((shadow - shadowPos.z) * 65536.0, 0.0, 1.0);
}
#endif

#ifdef VC_3_7
#if defined OVERWORLD
#if MC_VERSION >= 12104
uniform float isPaleGarden;
#endif

//biomeColor / isSpecificBiome / caveBiomeColor / isCaveBiome are shared with the 3.7 sky and
//are defined in /lib/color/lightColor.glsl when SKY_3_7 or VC_3_7 is enabled.
#endif

void getDynamicWeather(inout float speed, inout float amount, inout float thickness, inout float density, inout float detail, inout float height, inout float scale) {
	#ifdef VC_DYNAMIC_WEATHER
	float day = float(worldDay) + timeAngle;
    float sinDay05 = sin(day * 0.5);
    float cosDay075 = cos(day * 0.75);
    float cosDay15 = cos(day * 1.5);
    float sinDay2 = sin(day * 2.0);
    float waveFunction = sinDay05 * cosDay075 + sinDay2 * 0.25 - cosDay15 * 0.75;

    amount += waveFunction * (0.5 + cosDay075 * 0.5) * 0.5 + moonVisibility * 0.25;
    height += waveFunction * sinDay2 * 75.0;
    scale += waveFunction * cosDay075 - moonVisibility * 0.25;
    thickness += waveFunction * waveFunction * cosDay15;
    density += waveFunction * sinDay05;
	#endif

	#if MC_VERSION >= 12104
    amount -= isPaleGarden;
	#endif
}

float CloudLocalTop(float noiseBase) {
	float localTop = clamp((noiseBase - 0.48) * 2.15, 0.0, 1.0);
	      localTop = localTop * localTop * (3.0 - 2.0 * localTop);

	return mix(0.70, 1.08, localTop);
}

float CloudVerticalCoverage(float sampleAltitude, float noiseBase) {
	float localTop = CloudLocalTop(noiseBase);

	float bottomPenalty = (1.0 - smoothstep(0.00, 0.18, sampleAltitude)) * 0.35;
	float topPenalty = smoothstep(localTop - 0.20, localTop + 0.12, sampleAltitude) * 0.85;
	float planeGuard = smoothstep(0.94, 1.0, sampleAltitude) * 0.90;

	return bottomPenalty + max(topPenalty, planeGuard);
}

float CloudHeightDensity(float sampleAltitude, float noiseBase) {
	float localTop = CloudLocalTop(noiseBase);

	float bottomFade = smoothstep(0.00, 0.18, sampleAltitude);
	float bodyFade = 0.82 + smoothstep(0.16, 0.58, sampleAltitude) * 0.18;
	float topFade = 1.0 - smoothstep(localTop - 0.20, localTop + 0.14, sampleAltitude) * 0.45;
	float planeFade = 1.0 - smoothstep(0.965, 1.0, sampleAltitude);

	return clamp((0.30 + bottomFade * 0.70) * bodyFade * topFade * planeFade, 0.0, 1.08);
}

float cloudSampleBase(vec2 coord) {
	//3.7 clouds use the independent 3.7 noise texture (noise3_7) so the 2.3 noise.png stays untouched
	float perlinBase = texture2D(noise3_7, coord * 0.5 + vec2(0.17, -0.11)).r * 0.6;
	      perlinBase += texture2D(noise3_7, coord * 1.5 + vec2(-0.07, 0.19)).r * 0.4;
		  perlinBase = perlinBase * 0.9 + pow3(perlinBase) * 0.4;

	return clamp((perlinBase - 0.35) * 1.4 + 0.5, 0.0, 1.0);
}

float CloudSampleDetail(vec2 coord, float sampleAltitude, float thickness) {
	float detailZ = floor(sampleAltitude * float(thickness)) * 0.04;
	float detailFrac = fract(sampleAltitude * float(thickness));

	float noiseDetailLow = texture2D(noise3_7, coord.xy + detailZ).g;
	float noiseDetailHigh = texture2D(noise3_7, coord.xy + detailZ + 0.04).g;

	float noiseDetail = fmix(noiseDetailLow, noiseDetailHigh, detailFrac);

	return noiseDetail;
}

float CloudCoverageDefault(float sampleAltitude, float amount) {
	float noiseCoverage = abs(sampleAltitude - 0.125);

	noiseCoverage *= sampleAltitude > 0.125 ? (2.5 - amount * 0.1) : 8.0;
	noiseCoverage = noiseCoverage * noiseCoverage * 4.0;

	return noiseCoverage;
}

float CloudApplyDensity(float noise, float density) {
	noise *= density * 0.125;
	noise *= (1.0 - 0.25 * wetness);
	noise = noise / sqrt(noise * noise + 0.5);

	return noise;
}

float CloudCombineDefault(float noiseBase, float noiseDetail, float noiseCoverage, float amount, float density) {
	float noise = fmix(noiseBase, noiseDetail, 0.0476 * VC_DETAIL) * 21.0;

	noise = fmix(noise - noiseCoverage, 21.0 - noiseCoverage * 2.5, 0.2 * wetness);
	noise = max(noise - amount, 0.0);

	noise = CloudApplyDensity(noise, density);

	return noise;
}

float CloudSample(vec2 coord, vec2 wind, float sampleAltitude, float thickness, float amount, float density) {
	coord *= 0.0025;

	vec2 baseCoord = coord * 0.5 + wind * 2.0;
	vec2 detailCoord = coord.xy * 10.0 - wind * 2.0;

	float noiseBase = cloudSampleBase(baseCoord);
	float noiseDetail = CloudSampleDetail(detailCoord, sampleAltitude, thickness);
	float noiseCoverage = CloudCoverageDefault(sampleAltitude, amount);
	      noiseCoverage += CloudVerticalCoverage(sampleAltitude, noiseBase);

	float noise = CloudCombineDefault(noiseBase, noiseDetail, noiseCoverage, amount, density);
	      noise *= CloudHeightDensity(sampleAltitude, noiseBase);

	return noise;
}

float CloudSampleLowDetail(vec2 coord, vec2 wind, float sampleAltitude, float thickness, float amount, float density) {
	coord *= 0.0025;

	vec2 baseCoord = coord * 0.5 + wind * 2.0;

	float noiseBase = cloudSampleBase(baseCoord);
	float noiseCoverage = CloudCoverageDefault(sampleAltitude, amount);
	      noiseCoverage += CloudVerticalCoverage(sampleAltitude, noiseBase);

	float noise = CloudCombineDefault(noiseBase, 0.0, noiseCoverage, amount, density);
	      noise *= CloudHeightDensity(sampleAltitude, noiseBase);

	return noise;
}

float InvLerp(float v, float l, float h) {
	return clamp((v - l) / (h - l), 0.0, 1.0);
}

void computeVolumetricClouds3_7(inout vec4 vc, in vec3 atmosphereColor, float z, float dither, inout float currentDepth) {
	//Total visibility
	float visibility = caveFactor * int(0.56 < z);

	#if MC_VERSION >= 11900
	visibility *= 1.0 - darknessFactor;
	#endif

	visibility *= 1.0 - blindFactor;

    if (visibility > 0.0) {
		vec3 viewPos = ToView(vec3(texCoord, z));
		vec3 nViewPos = normalize(viewPos);
		vec3 worldPos0 = ToWorld(viewPos);
		vec3 nWorldPos = normalize(worldPos0);
        float lViewPos = length(viewPos);

		#if defined DISTANT_HORIZONS
		float dhZ = texture2D(dhDepthTex0, texCoord).r;
		vec4 dhScreenPos = vec4(texCoord, dhZ, 1.0);
		vec4 dhViewPos = dhProjectionInverse * (dhScreenPos * 2.0 - 1.0);
			    dhViewPos /= dhViewPos.w;
		float lDhViewPos = length(dhViewPos.xyz);
		#elif defined VOXY
		float vxZ = texture2D(vxDepthTexOpaque, texCoord).r;
		vec4 vxScreenPos = vec4(texCoord, vxZ, 1.0);
		vec4 vxViewPos = vxProjInv * (vxScreenPos * 2.0 - 1.0);
		        vxViewPos /= vxViewPos.w;
		float lVxViewPos = length(vxViewPos.xyz);
		#endif

		//Cloud parameters
		float speed = VC_SPEED;
		float amount = VC_AMOUNT;
		float thickness = VC_THICKNESS;
		float density = VC_DENSITY;
		float detail = VC_DETAIL;
		float height = VC_HEIGHT;
        float scale = VC_SCALE;
        float distance = VC_DISTANCE;

		getDynamicWeather(speed, amount, thickness, density, detail, height, scale);

        //Aurora influence
        #ifdef AURORA_LIGHTING_INFLUENCE
        //The index of geomagnetic activity. Determines the brightness of Aurora, its widespreadness across the sky and tilt factor
        float kpIndex = abs(worldDay % 9 - worldDay % 4);
              kpIndex = kpIndex - int(kpIndex == 1) + int(kpIndex > 7 && worldDay % 10 == 0);
              kpIndex = min(max(kpIndex, 0) + isSnowy * 4, 9);
        #ifdef AURORA_ALWAYS_VISIBLE
              kpIndex = 7;
        #endif

        //Total visibility of aurora based on multiple factors
        float auroraVisibility = pow6(moonVisibility) * (1.0 - wetness) * caveFactor;

        //Aurora tends to get brighter and dimmer when plasma arrives or fades away
        float pulse = 0.5 + 0.5 * sin(frameTimeCounter * 0.08 + sin(frameTimeCounter * 0.013) * 0.6);
              pulse = smoothstep(0.15, 0.85, pulse);

        float longPulse = sin(frameTimeCounter * 0.025 + sin(frameTimeCounter * 0.004) * 0.8);
              longPulse = longPulse * (1.0 - 0.15 * abs(longPulse));

        kpIndex *= 1.0 + longPulse * 0.25;
        kpIndex /= 9.0;

		//When aurora turns red
		float redPhase = pow3(kpIndex) * (1.0 - pulse);

        //Aurora distribution parameters
        float westEast = clamp(1.0 - abs(nWorldPos.x * 0.05) + kpIndex * kpIndex, 0.0, 1.0); //Fade out aurora closer to the western/eastern horizons
        float north = clamp(10.0 * kpIndex * kpIndex * kpIndex - nWorldPos.z, 0.0, 1.0); //Make aurora appear stronger in north when looking from the ground
        float auroraDistanceFactor = clamp(1.0 - length(nWorldPos.xz) * 0.02, 0.0, 1.0); //Limit the max render distance

        auroraVisibility *= kpIndex * (1.0 + max(longPulse * 0.5, 0.0));
        auroraVisibility = min(auroraVisibility, 2.0) * AURORA_BRIGHTNESS * 10;
        auroraVisibility *= auroraDistanceFactor * auroraDistanceFactor * north * westEast;

        float colorMixer = 0.65 + pow3(kpIndex) * pulse * 0.1;
        vec3 lowColor = vec3(0.45, 1.55 - redPhase * 0.5, 0.0);
        vec3 upColor = vec3(0.95 + redPhase * 5.0, 0.10, 0.0);
        vec3 auroraColor = fmix(lowColor, upColor, colorMixer);
        #endif

		//Ray marcher peramters
        int maxsampleCount = 24;

        float cloudBottom = height;
        float cloudSpan = thickness * scale * 1.18;
        float cloudTop = cloudBottom + cloudSpan;

        float lowerPlane = (cloudBottom - cameraPosition.y) / nWorldPos.y;
        float upperPlane = (cloudTop - cameraPosition.y) / nWorldPos.y;

        float nearestPlane = max(min(lowerPlane, upperPlane), 0.0);
        float farthestPlane = max(lowerPlane, upperPlane);

        float maxDist = currentDepth;

        if (farthestPlane > 0) {
            float planeDifference = farthestPlane - nearestPlane;

            float lengthScaling = abs(cameraPosition.y - (cloudTop + cloudBottom) * 0.5) / ((cloudTop - cloudBottom) * 0.5);
                  lengthScaling = clamp((lengthScaling - 1.0) * thickness * 0.125, 0.0, 1.0);

            float rayLength = thickness * scale / 2.0;
                  rayLength /= (4.0 * nWorldPos.y * nWorldPos.y) * lengthScaling + 1.0;

            vec3 rayIncrement = nWorldPos * rayLength;
            int sampleCount = int(min(planeDifference / rayLength, maxsampleCount) + 4);

            vec3 startPos = cameraPosition + nearestPlane * nWorldPos;
            vec3 rayPos = startPos + rayIncrement * dither;
            float sampleTotalLength = nearestPlane + rayLength * dither;

            float time = (timeAngle + float(worldDay % 100 + 5)) * 1200.0;
            vec2 wind = vec2(time * speed * 0.005, sin(time * speed * 0.1) * 0.01) * speed * 0.05;

            float cloud = 0.0;
            float cloudFaded = 0.0;
            float cloudLighting = 0.0;
			float ambientLighting = 0.0;

            vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);
            float VoL = dot(nViewPos, lightVec);

            float halfVoL = fmix(abs(VoL) * 0.8, VoL, shadowFade) * 0.5 + 0.5;
            float halfVoLSqr = halfVoL * halfVoL;
            float scattering = pow8(halfVoL);

            float distanceFade = 1.0;
            float fadeStart = 32.0 / max(FOG_DENSITY, 0.5);
            float fadeEnd = distance / max(FOG_DENSITY, 0.5);

            float xzNormalizeFactor = 10.0 / max(abs(height - 72.0), 56.0);

			vec3 worldLightVec = normalize(ToWorld(lightVec * 100000000.0));
                 worldLightVec *= (4.0 - scattering * scattering * 2.0) * shadowFade;

            for (int i = 0; i < sampleCount; i++, rayPos += rayIncrement, sampleTotalLength += rayLength) {
                if (cloud > 0.99 || (lViewPos < sampleTotalLength && z < 1.0) || sampleTotalLength > distance * 32.0) break;

				#if defined DISTANT_HORIZONS
				if ((lDhViewPos < sampleTotalLength && dhZ < 1.0)) break;
				#elif defined VOXY
				if ((lVxViewPos < sampleTotalLength && vxZ < 1.0)) break;
				#endif

                vec3 worldPos = rayPos - cameraPosition;
				float lWorldPos = length(worldPos.xz);

				//Indoor leak prevention
				if (eyeBrightnessSmooth.y < 210.0 && cameraPosition.y > height - 50.0 && lWorldPos < shadowDistance) {
					if (texture2DShadow(shadowtex1, ToShadow(worldPos)) <= 0.0) break;
				}

                float xzNormalizedDistance = length(rayPos.xz - cameraPosition.xz) * xzNormalizeFactor;
                vec2 cloudCoord = rayPos.xz / scale;

				float sampleAltitude = InvLerp(rayPos.y, cloudBottom, cloudTop);
                float attenuation = step(cloudBottom, rayPos.y) * step(rayPos.y, cloudTop);

                float noise = CloudSample(cloudCoord, wind, sampleAltitude, thickness, amount, density);
                      noise *= attenuation * step(xzNormalizedDistance, fadeEnd);

                if (noise <= 0.0001) continue;

				float sampleAltitudeL = InvLerp(rayPos.y + worldLightVec.y, cloudBottom, cloudTop);
                float attenuationL = step(cloudBottom, rayPos.y + worldLightVec.y) * step(rayPos.y + worldLightVec.y, cloudTop);

                float lightingNoise = CloudSampleLowDetail(cloudCoord + worldLightVec.xy, wind, sampleAltitudeL, thickness, amount, density);
                      lightingNoise *= attenuationL;

				float powder = 1.0 - exp(-pow4(noise) * 0.75);
				float lightTransmittance = exp(-lightingNoise * (4.0 - timeBrightness)) * (1.0 + scattering * scattering);
				float sampleLighting1 = clamp(powder * lightTransmittance, 0.0, 1.0);
                float sampleLighting2 = clamp(sampleAltitude * (2.0 + lightTransmittance * 2.0 - scattering * scattering), 0.0, 1.0);

                cloudLighting = fmix(cloudLighting, sampleLighting1, noise * (1.0 - cloud * cloud));
				ambientLighting = fmix(ambientLighting, sampleLighting2, noise * (1.0 - cloud * cloud));

                float sampleFade = InvLerp(xzNormalizedDistance, fadeEnd, fadeStart);
                distanceFade *= fmix(1.0, sampleFade, noise * (1.0 - cloud));

                cloud = fmix(cloud, 1.0, noise);

                cloudFaded = fmix(cloudFaded, 1.0, noise);

                if (currentDepth == maxDist && cloud > 0.5) {
                    currentDepth = sampleTotalLength;
                }
            }

            cloudFaded *= distanceFade;
			if (cloudFaded < dither) {
				currentDepth = maxDist;
			}

            //Final color calculations
			vec3 nSkyColor = normalize(skyColor + 0.0001);
            vec3 atmColor22 = pow(atmosphereColor, vec3(2.2));
            vec3 cloudAmbientColor = fmix(atmColor22, atmColor22 * mix(vec3(1.0), nSkyColor * 0.5, isSpecificBiome), timeBrightnessSqrt) * (0.75 + scattering * 0.25 - wetness * 0.5);

            vec3 cloudLightColor = fmix(lightCol, lightCol * nSkyColor * 2.0, timeBrightnessSqrt);
                 cloudLightColor *= 0.125 + cloudLighting * ((0.475 + 0.4 * shadowFade + moonVisibility * 0.4) + scattering * 1.825);
				 cloudLightColor = fmix(cloudAmbientColor, cloudLightColor, fmix(0.5 + cloudLighting, 1.0, scattering));
                //Aurora influence
                #ifdef AURORA_LIGHTING_INFLUENCE
                //The 2.3 tonemap exposes brighter (TONEMAP_BRIGHTNESS 4.7 vs 3.7's 3.6), so the aurora
                //lit cloud top is scaled up (2.6 ≈ 2.0 * 4.7/3.6) to match the 2.3 exposure.
                 cloudLightColor *= 1.0 + auroraColor * auroraVisibility * 2.6;
                 cloudLightColor /= 1.0 + auroraVisibility * 1.3;
                #endif
			vec3 cloudColor = fmix(cloudAmbientColor, cloudLightColor, ambientLighting) * fmix(vec3(1.0), biomeColor, isSpecificBiome * sunVisibility);

            float opacity = clamp(fmix(VC_OPACITY * (1.0 - wetness * 0.25), 1.0, (max(0.0, cameraPosition.y - thickness * 10.0) / height)), 0.0, 1.0);

            #if MC_VERSION >= 12104
            opacity = fmix(opacity, opacity * 0.5, isPaleGarden);
            #endif

            cloudFaded = pow(max(cloudFaded, 0.0), 1.82) * opacity;
            vc = vec4(cloudColor, cloudFaded * visibility);
        }
    }
}
#endif
