//End Nebula 3.7 + End Black Hole (ported from Solas Shader 3.7, independent controls).
//Gated by END_NEBULA_3_7 (nebula band) and END_BLACK_HOLE_3_7 (black hole warping + photon
//ring). Included from deferred2.glsl only when END_NEBULA_3_7 is defined.

void sampleNebulaNoise3_7(vec2 coord, inout float colorMixer, inout float noise) {
    colorMixer = texture2D(noisetex, coord * 0.25).r;
    noise = texture2D(noisetex, coord * 0.50).r;
    noise *= colorMixer;
    noise *= texture2D(noisetex, coord * 0.125).r;
    noise *= 2.0 + noise * 20.0;
}

float getSpiralWarping3_7(vec2 coord, float gravityLens) {
	float whirl = -15.0;
	float arms = 15.0;

    coord = vec2(atan(coord.y, coord.x) + frameTimeCounter * 0.1, sqrt(coord.x * coord.x + coord.y * coord.y));
    float center = pow8(1.0 - coord.y) * 24.0;
    float spiral = sin((coord.x + sqrt(coord.y) * whirl) * arms) + center - coord.y;

    return clamp(spiral * 0.025, 0.0, 1.0);
}

#if MC_VERSION >= 12100 && defined END_FLASHES
float endFlashIntensitySqrt3_7 = sqrt(endFlashIntensity);

vec4 getSupernovaAtPos3_7(in vec3 flashPos, in vec3 worldPos) {
    vec2 flashCoord = flashPos.xz / (flashPos.y + length(flashPos));
    vec2 blackHoleCoord = worldPos.xz / (length(worldPos) + worldPos.y) - flashCoord;

    float nebulaNoise = 0.0;
    float nebulaColorMixer = 0.0;
    sampleNebulaNoise3_7(blackHoleCoord, nebulaColorMixer, nebulaNoise);
          nebulaColorMixer = pow4(nebulaColorMixer) * 6.0;

    float endFlashPoint = 1.0 - clamp(length(blackHoleCoord), 0.0, 1.0);
    float animation = endFlashIntensitySqrt3_7 * 17.0;
    float visibility = pow(endFlashPoint, 20.0 - animation) * max(1.0 - (1.0 + endFlashIntensity) * pow(endFlashPoint, 24.0 - animation), 0.0);

    return vec4(nebulaNoise, nebulaColorMixer, visibility, endFlashPoint);
}
#endif

vec2 rotate2D3_7(vec2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat2(c, -s,
                s,  c) * p;
}

void drawEndNebula3_7(inout vec3 color, in vec3 worldPos, in float VoU, in float VoS) {
    #ifdef END_BLACK_HOLE_3_7
    //Prepare black hole parameters for warping the nebula
    vec3 blackHoleColor = vec3(5.6, 3.2, 0.7) * endLightCol;
    float absVoU = abs(VoU);
    float sqrtabsVoU = sqrt(absVoU);
    float blackHoleSize = END_BLACK_HOLE_SIZE_3_7;
    float hole = pow(pow4(pow32(VoS)), blackHoleSize);
    float gravityLens = hole;
    hole *= hole;
    hole *= hole;

    vec3 wSunVec = mat3(gbufferModelViewInverse) * sunVec;
    vec2 sunCoord = wSunVec.xz / (wSunVec.y + length(wSunVec));
    vec2 blackHoleCoord = worldPos.xz / (length(worldPos) + worldPos.y) - sunCoord;
    blackHoleCoord.y -= blackHoleCoord.x * END_ANGLE_3_7;
    #ifdef END_67
    if (frameCounter < 500) {
        blackHoleCoord.y -= blackHoleCoord.x * 0.5 * sin(frameTimeCounter * 8);
    }
    #endif
    #ifdef END_TIME_TILT
          blackHoleCoord.y -= blackHoleCoord.x * min(0.025 * frameTimeCounter, 1.0);
    #endif
    float warping = getSpiralWarping3_7(blackHoleCoord, gravityLens);
         blackHoleCoord.x *= 0.75 - absVoU * 0.25;
         blackHoleCoord.y *= 5.0;
         blackHoleCoord.y += pow2(blackHoleCoord.x * 2.25) * sqrtabsVoU;
    #endif

    //Ender Nebula (only when the 3.7 nebula is on)
    #ifdef END_NEBULA_3_7
    vec2 nebulaCoord = worldPos.xz / (length(worldPos.y) + length(worldPos.xyz));
    #ifdef END_BLACK_HOLE_3_7
         nebulaCoord += warping * gravityLens;
    #endif
         nebulaCoord += cameraPosition.xz * 0.0001;

    float nebulaNoise = 0.0;
    float nebulaColorMixer = 0.0;
    sampleNebulaNoise3_7(nebulaCoord, nebulaColorMixer, nebulaNoise);
          nebulaColorMixer = pow3(nebulaColorMixer) * 4.5;

    float nebulaVisibility = 1.0;
    #ifdef END_BLACK_HOLE_3_7
          nebulaVisibility = (0.175 - pow3(VoS) * 0.175) + pow20(VoS) * 0.425;
    #endif

    vec3 nebula = fmix(endNebulaColFirst,
                      endNebulaColSecond,
                      nebulaColorMixer) * nebulaNoise * nebulaNoise * nebulaVisibility;
    #ifdef END_BLACK_HOLE_3_7
         nebula *= 1.0 + blackHoleColor * pow24(VoS) * 0.25;
         nebula *= max(1.0 - pow32(VoS), 0.0);
    #endif
         nebula *= length(nebula) * END_NEBULA_BRIGHTNESS_3_7;

    color += nebula;

    //Supernova in 1.21.8
    #if MC_VERSION >= 12100 && defined END_FLASHES
    vec4 supernova = getSupernovaAtPos3_7(mat3(gbufferModelViewInverse) * endFlashPosition, worldPos);

    vec3 supernovaNebula = fmix(normalize(endFlashCol), normalize(vec3(1.0, 1.8, 3.2)), supernova.y) * 4.0 * supernova.x * supernova.x * supernova.z;
         supernovaNebula *= length(supernovaNebula);
    color += pow32(supernova.a * supernova.a) * endLightColSqrt * endFlashIntensity * 4.0;
    color += supernovaNebula * endFlashIntensitySqrt3_7 * END_FLASH_BRIGHTNESS;
    #endif
    #endif //END_NEBULA_3_7

    //Black Hole
    #ifdef END_BLACK_HOLE_3_7
    float photonRing = pow2(hole * 3.0);
            photonRing *= float(photonRing > 0.2) * (1.0 - 6.0 * hole) * 64.0;
            photonRing = max(photonRing, 0.0);
          hole = clamp(hole * 8.0, 0.0, 1.0);

    float torus = 1.0 - clamp(length(blackHoleCoord), 0.0, 1.0);
            torus = pow(pow(torus * torus, 1.0 + (180.0 - abs(sunPathRotation)) / 8.0 * (0.5 + 0.5 * sqrtabsVoU)), sqrt(blackHoleSize) * 1.5);

    vec2 noiseCoord = blackHoleCoord - hole * hole;
            noiseCoord = rotate2D3_7(noiseCoord, PI);
            noiseCoord -= vec2(frameTimeCounter * 0.025, 0.0);
            noiseCoord.y *= 0.33;
            noiseCoord *= 2.0;

    float blackHoleNoise = texture2D(noisetex, noiseCoord).r;

    color += fmix(blackHoleColor, vec3(4.0 + hole * hole * 2.0), hole * hole) * hole * hole * 3.0 * blackHoleNoise;
    color *= 1.0 - hole;
    color += vec3(photonRing);
    color += fmix(blackHoleColor, vec3(2.0 + torus * 6.0), pow(torus, 0.33)) * torus * pow2(1.0 - torus * 0.65) * blackHoleNoise * 3.0;
    #endif
}
