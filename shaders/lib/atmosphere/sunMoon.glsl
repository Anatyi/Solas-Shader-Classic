void getSunMoon(inout vec3 color, in vec3 nViewPos, in vec3 worldPos, in vec3 lightSun, in vec3 lightNight, in float VoS, in float VoM, in float VoU, in float caveFactor) {
	float visibility = (1.0 - rainStrength) * caveFactor;

	if (visibility > 0.0) {
		#ifdef VANILLA_SUN_MOON
		//Vanilla sun/moon (shape from sun.png / moon_phases.png) is re-colored in
		//gbuffers_skytextured and composited in deferred2 - nothing is drawn here.
		#else
		float sun = pow16(pow32(VoS * VoS));
		float moon = pow32(pow32(VoM));
		float glare = pow24(VoS + VoM);

		if (moon > 0.0 && moonPhase > 0) { // Moon phases, uses the same method as Complementary v4
			float phaseFactor = int(moonPhase != 4) * (1.0 - int(moonPhase > 4) * 2.0) * 0.00175;

			const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
			float ang = fract(timeAngle - (0.25 + phaseFactor));
			ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * TAU;
			vec3 newSunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

			moon *= clamp(1.0 - pow20(pow32(dot(nViewPos, newSunVec))), 0.0, 1.0);
		}

		vec3 sunColor = sun * normalize(lightSun) * 2.0;
		     sunColor *= pow4(min(length(sunColor), 1.0)) * 2.0;
		vec3 moonColor = moon * lightNight * (10.0 + int(moonPhase == 4) * 2.0);
		     moonColor *= pow6(min(length(moonColor), 1.0));
		vec3 glareColor = glare * lightColSqrt * 0.5;

		if (moonPhase == 0) {
			worldPos = normalize(worldPos);
			vec2 planeCoord = worldPos.xz / (worldPos.y + length(worldPos));
			moonColor *= texture2D(noisetex, planeCoord * 0.9).r + 0.5;
		}

		vec3 sunMoonColor = sunColor + moonColor + glareColor;
			 sunMoonColor = max(sunMoonColor, 0.0) * visibility;

		color += sunMoonColor * clamp(VoU, 0.0, 1.0);
		#endif
	}
}

//Sun & Moon 3.7 Style (ported from Solas Shader 3.7)//
//Active with SUN_MOON_3_7 (default off). Uses the 3.7 sun/moon disc: height-based space transition
//(spaceFactor, Karman line), occlusion from clouds/aurora, 3.7 glare/moon-phase math. Replaces the
//2.3 getSunMoon in deferred2.
#ifdef SUN_MOON_3_7
void drawSunMoon3_7(inout vec3 color, in vec3 worldPos, in vec3 nViewPos, in float VoU, in float VoS, in float VoM, in float caveFactor, inout float occlusion) {
    float spaceFactor = min(max(cameraPosition.y, 0.0) / KARMAN_LINE, 1.0);
    float visibility = (1.0 - wetness) * caveFactor * (1.0 - occlusion);
            visibility *= fmix(sqrt(max(VoU, 0.0)), 1.0, spaceFactor);

    if (visibility > 0.0) {
        float sun = max(pow32(pow32(VoS)) - 0.4, 0.0) * 16.0 * sunVisibility;
        float moon = max(pow32(pow32(VoM)) - 0.4, 0.0);
                moon = float(moon > 0.0) * 2.0 * moonVisibility;
        float glare = pow32(VoS * sunVisibility + VoM * moonVisibility) * 0.25;

        // Moon phases and texture
        if (moon > 0.0) {
            if (moonPhase > 0) {
                float phaseFactor = int(moonPhase != 4) * (-1.0 + int(4 < moonPhase) * 2.0) * 0.00125;

                const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
                float fractTimeAngle = fract(timeAngle - (0.25 + phaseFactor));
                float ang = (fractTimeAngle + (cos(fractTimeAngle * PI) * -0.5 + 0.5 - fractTimeAngle) / 3.0) * TAU;
                vec3 newSunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

                moon *= 0.035 + clamp(1.0 - max(pow24(pow32(dot(nViewPos, newSunVec))) - 0.5, 0.0) * 16.0, 0.0, 1.0);
            }
        }

        color += glare * lightColSqrt * visibility * (1.0 - spaceFactor);
        color += mix(lightCol, vec3(0.4, 0.38, 0.36), spaceFactor) * sun * visibility;
        color += normalize(mix(lightCol, sqrt(lightNight), clamp(VoU + spaceFactor, 0.0, 1.0))) * moon * visibility;
        occlusion += (sun + moon) * 16.0;
    }
}
#endif