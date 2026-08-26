//3.7 planar clouds (ported). Active only with PLANAR_CLOUDS_3_7 (default off).
//Samples the independent 3.7 noise texture (noise3_7) like the other 3.7 sky elements,
//and uses its own PLANAR_CLOUDS_3_7_* controls. Signature matches the 2.3 drawPlanarClouds
//so it can replace it at the call site.
//Dependencies: noise3_7, KARMAN_LINE, moonVisibility (defined when PLANAR_CLOUDS_3_7 is on),
//timeBrightnessSqrt, sunVisibility, shadowFade, lightCol, wetness, cameraPosition,
//frameTimeCounter, ToWorld, worldDay (only under AURORA_3_7 && AURORA_LIGHTING_INFLUENCE).

float samplePlanarCloudNoise3_7(vec2 coord) {
    coord = vec2(
        coord.x * 1.25 + coord.y * 0.5,
        coord.y * 0.65
    );

    float base = texture2D(noise3_7, coord * 0.035).r;
    float breakup = texture2D(noise3_7, coord * 0.07).g;
    float detail = texture2D(noise3_7, coord * 2.0).r;

    base *= base;

    float noise = base * (1.0 - breakup * 0.75);

    noise += (detail - 0.5) * 0.05;
    float amount = PLANAR_CLOUDS_3_7_AMOUNT + moonVisibility * 0.05;
    noise = smoothstep(
        amount,
        amount + 0.35,
        noise
    );

    return clamp(pow(noise, 1.5), 0.0, 1.0);
}

void drawPlanarClouds3_7(inout vec3 color, in vec3 atmosphereColor, in vec3 worldPos, in vec3 viewPos, in float VoU, in float caveFactor, in float volumetricClouds, inout float pc) {
    vec3 lightVec = sunVec * ((timeAngle < 0.5325 || timeAngle > 0.9675) ? 1.0 : -1.0);

    float spaceFactor = min(max(cameraPosition.y, 0.0) / KARMAN_LINE, 1.0);
    float spaceFactor10k = min(max(cameraPosition.y, 0.0) * 0.0001, 1.0);
    float cloudHeightFactor = 0.125 + pow2(clamp(1.0 - 0.001 * cameraPosition.y * (0.5 - spaceFactor), 0.0, 3.5));

    //Sampling
	vec3 planeCoord = worldPos * (cloudHeightFactor / worldPos.y) * PLANAR_CLOUDS_3_7_HEIGHT * 0.001;
    float coordLength = length(planeCoord.xz);
    float distanceFactor = clamp(1.0 - coordLength * max(0.15 - spaceFactor * 0.085 - spaceFactor10k * (1.0 - spaceFactor) * 0.25, 0.005), 0.0, 1.0);
    planeCoord *= 2.0 - distanceFactor;

	if (distanceFactor > 0.0) {
        vec2 warp;
        warp.x = sin(planeCoord.z * 0.5 - frameTimeCounter * 0.001);
        warp.y = cos(planeCoord.x * 0.3 - frameTimeCounter * 0.002);

        planeCoord.xz += warp * 0.5;

		vec2 coord = cameraPosition.xz * 0.00025 * (0.5 - spaceFactor10k) + planeCoord.xz * 1.25 + frameTimeCounter * 0.005;
		vec3 worldLightVec = normalize(ToWorld(lightVec * 100000000.0));
		float noise = samplePlanarCloudNoise3_7(coord);
		float lightingNoise = samplePlanarCloudNoise3_7(coord + worldLightVec.xz * 0.025);

		//Lighting and coloring
        vec3 nWorldPos = normalize(worldPos);
        float fade = pow(max(nWorldPos.y, 0.0), 0.025);
                fade = mix(fade, (1.0 - fade) * float(nWorldPos.y < 0.0), spaceFactor10k);
                fade *= pow3(fade);
                fade *= distanceFactor;

		float cloudSample = sqrt(noise) * fade * caveFactor;

        float noiseDiff = clamp(noise - lightingNoise, 0.0, 1.0);
		float cloudLighting = (0.25 + noiseDiff * shadowFade * 2.0) * (1.0 - noise * noise * (1.0 - spaceFactor10k) * 0.75) * 2.0;

		float VoL = dot(normalize(viewPos), lightVec);

		float halfVoL = fmix(abs(VoL) * 0.8, VoL, shadowFade) * 0.5 + 0.5;
		float scattering = pow12(halfVoL);

        //Aurora influence (3.7, only when the 3.7 aurora is on)
        #if defined AURORA && defined AURORA_3_7 && defined AURORA_LIGHTING_INFLUENCE
        float kpIndex = abs(worldDay % 9 - worldDay % 4);
              kpIndex = kpIndex - int(kpIndex == 1) + int(kpIndex > 7 && worldDay % 10 == 0);
              kpIndex = min(max(kpIndex, 0) + isSnowy * 3, 9);
        #ifdef AURORA_ALWAYS_VISIBLE
              kpIndex = 7;
        #endif
        float auroraVisibility = pow6(moonVisibility) * (1.0 - wetness) * caveFactor;
        float pulse = 0.5 + 0.5 * sin(frameTimeCounter * 0.08 + sin(frameTimeCounter * 0.013) * 0.6);
              pulse = smoothstep(0.15, 0.85, pulse);
        float longPulse = sin(frameTimeCounter * 0.025 + sin(frameTimeCounter * 0.004) * 0.8);
              longPulse = longPulse * (1.0 - 0.15 * abs(longPulse));
        kpIndex *= 1.0 + longPulse * 0.25;
        kpIndex /= 9.0;
        float redPhase = pow3(kpIndex) * (1.0 - pulse);
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
        #endif

		vec3 nSkyColor = normalize(atmosphereColor + 0.0001);
		vec3 cloudLightColor = fmix(lightCol, lightCol * nSkyColor * 2.0, timeBrightnessSqrt * (0.5 - wetness * 0.5));
             cloudLightColor *= 0.25 + sunVisibility * 0.5 + moonVisibility * 0.5 + 2.0 * scattering;
            #if defined AURORA && defined AURORA_3_7 && defined AURORA_LIGHTING_INFLUENCE
             cloudLightColor *= 1.0 + auroraColor * auroraVisibility * 2.0;
             cloudLightColor /= 1.0 + auroraVisibility;
            #endif

		//2.3-style output: pc = cloud occlusion for stars/sun, color gets blended
		pc = cloudSample * (1.0 - volumetricClouds) * (1.0 - wetness);
		color = mix(color, pow(cloudLightColor * cloudLighting * noise * PLANAR_CLOUDS_3_7_BRIGHTNESS, vec3(1.0 / 2.2)), pc * PLANAR_CLOUDS_3_7_OPACITY);
	}
}
