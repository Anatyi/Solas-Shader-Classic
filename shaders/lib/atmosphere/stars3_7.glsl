//3.7 starfield + shooting stars (ported). Active only with STARS_3_7 (default off).
//Reuses the 2.3 STAR_BRIGHTNESS / STAR_AMOUNT / STAR_SIZE controls.
//Functions are named *3_7 / renamed to avoid clashing with the 2.3 drawStars/getNoise in skyEffects.glsl.
//Dependencies: KARMAN_LINE, moonVisibility (defined when STARS_3_7 is on), lightNight, wetness,
//caveFactor, cameraPosition, frameTimeCounter.

float getNoise3_7(vec2 pos) {
	return fract(sin(dot(pos, vec2(12.9898, 4.1414))) * 43758.5453);
}

#ifdef STARS_3_7
void drawStars3_7(inout vec3 color, in vec3 worldPos, in float VoU, in float caveFactor, in float nebulaFactor, in float occlusion, in float size) {
	float spaceFactor = min(max(cameraPosition.y, 0.0) / KARMAN_LINE, 1.0);
	float visibility = moonVisibility * moonVisibility * (1.0 - wetness) * sqrt(max(VoU, 0.0)) * caveFactor * (1.0 - occlusion) * (1.0 - spaceFactor) + spaceFactor * sqrt(VoU * 0.5 + 0.5);

	if (visibility > 0.05) {
		vec2 planeCoord = worldPos.xz / (length(worldPos.y) + length(worldPos.xyz));
                planeCoord *= 0.8 / size;
                planeCoord += cameraPosition.xz * 0.00001;
                planeCoord += frameTimeCounter * 0.001;

		float amount = STAR_AMOUNT;

		vec2 planeCoord0 = floor(planeCoord * 500.0 * amount) / (500.0 * amount);
		vec2 planeCoord1 = floor(planeCoord * 1000.0 * amount) / (1000.0 * amount);

		float starNoise = getNoise3_7(planeCoord0 + 8.0);
                starNoise*= getNoise3_7(planeCoord1 + 14.0);

        float stars = clamp(starNoise - (0.825 - nebulaFactor * 0.125), 0.0, 1.0);
                stars *= stars * stars * 512.0;
                stars = clamp(stars, 0.0, 16.0);

		color += (stars + pow2(max(starNoise - 0.95, 0.0)) * 2048.0) * mix(lightNight, vec3(0.25), 0.35 + 0.25 * spaceFactor) * visibility * STAR_BRIGHTNESS;
	}
}
#endif

//3.7 End starfield (END_STARS_3_7, default off): the 3.7 drawStars END branch - random bright
//points that cluster into constellation-like patterns, blended with a uniform 1.0 visibility.
//Dependencies: getNoise3_7, STAR_AMOUNT/STAR_BRIGHTNESS/STAR_SIZE, frameTimeCounter,
//cameraPosition, nebulaFactor, VoS (black-hole lensing only when END_BLACK_HOLE_3_7 is on).
#ifdef END_STARS_3_7
void drawEndStars3_7(inout vec3 color, in vec3 worldPos, in float nebulaFactor, in float VoS, in float blackHoleDim, in float bhLensRing, in float bhLensSize) {
	float visibility = 1.0;

	if (visibility > 0.05) {
		vec2 planeCoord = worldPos.xz / (length(worldPos.y) + length(worldPos.xyz));
			 planeCoord *= 0.8 / END_STARS_3_7_SIZE;
			 #if defined END_BLACK_HOLE_3_7 || defined END_VORTEX_LENS
			 //Gravitational lensing + vortex shear (3.7 black hole or 2.3 vortex lens): Einstein
			 //ring push + spiral shear so nearby stars swirl inward around the hole. Uses the
			 //caller-computed ring/size (identical to the 2.3 drawStars behaviour).
			 float baseRing = bhLensRing;
			 planeCoord *= clamp(1.0 - baseRing * 4.0, 0.0, 1.0);
			 planeCoord += baseRing;
			 vec2 bhCenter = vec2(bhLensRing);
			 vec2 bhRel = planeCoord - bhCenter;
			 float bhR = length(bhRel);
			 //Vortex radius follows the black hole size control (small size value = big hole =
			 //wider vortex), mapped onto the star-plane scale for a visible falloff.
			 float bhVortexRange = mix(0.08, 0.45, (3.0 - bhLensSize) / 2.75);
			 #ifdef END_VORTEX_LENS
			 //Gravitational distortion range: radius uses the absolute value so the falloff
			 //always decays outward; the sign flips the rotation direction.
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

float amount = END_STARS_3_7_AMOUNT;
		vec2 planeCoord0 = floor(planeCoord * 500.0 * amount) / (500.0 * amount);
		vec2 planeCoord1 = floor(planeCoord * 1000.0 * amount) / (1000.0 * amount);
		float starNoise = getNoise3_7(planeCoord0 + 8.0);
		      starNoise *= getNoise3_7(planeCoord1 + 14.0);

		//3.7 Ender starfield values (identical to the 3.7 drawStars END branch): threshold 0.825,
		//brightness stars^3 * 512, ceiling 16. The star density is INDEPENDENT of the vanilla End
		//nebula (nebulaFactor is deliberately not used) so turning on END_NEBULA cannot crowd the
		//starfield near the nebula. END_STARS_3_7_NOISE (default 1.25) adjusts density: each +1.0
		//NOISE lowers the threshold by 0.10 (more stars).
		float stars = clamp(starNoise - 0.825 + (END_STARS_3_7_NOISE - 1.0) * 0.10, 0.0, 1.0);
		      stars *= stars * stars * 512.0;
		      stars = clamp(stars, 0.0, 16.0);

		//Dim the starfield around the black hole / vortex (caller passes the dim factor: the 3.7
		//hole uses its size control, the 2.3 vortex a fixed size - same as the 2.3 drawStars).
		stars *= blackHoleDim;

		color = fmix(color, color * (4.0 + pow4(stars)) * visibility * END_STARS_3_7_BRIGHTNESS, min(1.0, stars));
	}
}
#endif

// Shooting stars implementation based on https://www.shadertoy.com/view/ttVXDy and also based on https://github.com/OUdefie17/Photon-GAMS
// Credits to SpacEagle17 for allowing me to use shooting stars from his Euphoria Patches shader :P

#ifdef SHOOTING_STARS
const vec2 startPositions[10] = vec2[](
    vec2(-0.4, 0.3),
    vec2(0.2, 0.4),
    vec2(-0.1, -0.3),
    vec2(0.3, -0.2),
    vec2(-0.3, 0.1),
    vec2(0.5, 0.2),
    vec2(-0.5, -0.1),
    vec2(0.1, 0.5),
    vec2(-0.2, -0.4),
    vec2(0.4, -0.3)
);

const vec2 directions[10] = vec2[](
    vec2(0.7071, 0.7071),
    vec2(0.7071, -0.7071),
    vec2(-1.0, 0.0),
    vec2(1.0, 0.0),
    vec2(0.5299, 0.8480),
    vec2(-0.6000, 0.8000),
    vec2(0.9134, -0.4067),
    vec2(-0.8000, -0.6000),
    vec2(0.3015, 0.9535),
    vec2(-0.2000, -0.9798)
);

// Calculate distance from point p to line segment from a to b
float DistLine(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * t);
}

// Draw a line with smooth edges
float DrawLine(vec2 p, vec2 a, vec2 b) {
    float d = DistLine(p, a, b);
    float m = smoothstep(SHOOTING_STARS_LINE_THICKNESS * 0.01, 0.00001, d);
    float d2 = length(a - b);
    m *= smoothstep(1.0, 0.5, d2) + smoothstep(0.04, 0.03, abs(d2 - 0.75));
    return m;
}

float hash12(vec2 p) {
    vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

mat2 rotate(float angle) {
    float s = sin(angle), c = cos(angle);
    return mat2(c, -s, s, c);
}

// Generate a single shooting star
float drawShootingStar(vec2 uv, vec2 startPos, vec2 direction) {
    vec2 id = floor(uv * 0.5);
    float h = hash12(id);
    float worldDayFactor = abs(worldDay % 7 - worldDay % 5 * 0.5) / 6.0;

    if (h >= pow(SHOOTING_STARS_CHANCE * worldDayFactor * 0.05, 1.5)) return 0.0;

    vec2 gv = fract(uv * 0.5) * 2.0 - 1.0;
    float line = DrawLine(gv, startPos, startPos + direction * 0.9);

    vec2 toStart = gv - startPos;
    float alongTrail = dot(toStart, direction);
    float trail = smoothstep(SHOOTING_STARS_TRAIL_LENGTH, -0.1, alongTrail);

    float headBrightness = 1.0 + 3.0 / (1.0 + pow2((alongTrail - 1.0) * 8.0));

    return line * trail * headBrightness;
}

void getShootingStars(inout vec3 color, in vec3 worldPos, float VoU) {
    float burnTime = max(cos(sin(frameTimeCounter * 0.35) * 4.0 + frameTimeCounter * 0.25), 0.0) * 10.0;
	float visibility = moonVisibility * moonVisibility * (1.0 - wetness) * VoU * caveFactor * burnTime;

    if (visibility > 0.01) {
        vec2 planeCoord = worldPos.xz / (length(worldPos.y) + length(worldPos.xz) * 0.25);
        vec2 uv = planeCoord * 8.0 * (1.0 - SHOOTING_STARS_SIZE);
        float speed = frameTimeCounter * SHOOTING_STARS_SPEED;

        float stars = 0.0;
        int dayIndex = int(worldDay) % 10;
        vec2 todayDirection = directions[dayIndex];

        for (int i = 0; i < SHOOTING_STARS_COUNT; i++) {
            float offsetAngle = (hash12(vec2(i, worldDay)) - 0.5) * 0.66;
            vec2 starDirection = rotate(offsetAngle) * todayDirection;

            vec2 offsetUV = uv + starDirection * speed * (0.8 + 0.04 * float(i));
            stars += drawShootingStar(offsetUV, startPositions[i], starDirection);
        }

        float intensity = min(stars * visibility * 10.0, 1.0);
        color += vec3(0.38, 0.4, 0.5) * intensity;
    }
}
#endif
