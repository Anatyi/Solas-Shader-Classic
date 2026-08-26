//Nether Smoke 3.7 (下界烟雾), ported from Solas Shader 3.7.
//Independent control NETHER_SMOKE_3_7 (default off). Included from composite3.glsl.
//3.7-style volumetric nether smoke: rising smoke columns driven by a 3D noise, sampled along
//the view ray inside the nether (y 40..255, within 128 blocks of the camera). Independent of
//the 2.3 NETHER_CLOUDY_FOG (LPV-based) so they can be combined or used alone.
//Dependencies: texCoord, depthtex0/1, ToView/ToWorld, getLinearDepth2, noisetex, netherColor
//(fogColor -> netherColSqrt), frameTimeCounter, cameraPosition, isEyeInWater, blindFactor,
//darknessFactor, far/near, fmix.

#ifndef TEXTURE2D_SHADOW_DEFINED
#define TEXTURE2D_SHADOW_DEFINED
float texture2DShadow(sampler2D shadowtex, vec3 shadowPos) {
    float shadow = texture2D(shadowtex, shadowPos.xy).r;
    return clamp((shadow - shadowPos.z) * 65536.0, 0.0, 1.0);
}
#endif

#ifdef NETHER_SMOKE_3_7
float getNetherFogSample3_7(vec3 fogPos) {
    float t = frameTimeCounter;

    fogPos.y -= t * 2.0;
    fogPos.x += cos(fogPos.y * 0.09 + fogPos.z * 0.007 + t * 0.13) * 6.0;
    fogPos.z += sin(fogPos.y * 0.11 + fogPos.x * 0.007 + t * 0.09) * 6.0;

    float yIdx = fogPos.y * 0.075;
    float n0 = texture2D(noisetex, fogPos.xz * 0.0045 + floor(yIdx) * 0.137).r;
    float n1 = texture2D(noisetex, fogPos.xz * 0.0045 + (floor(yIdx) + 1.0) * 0.137).r;
    float smoke = fmix(n0, n1, smoothstep(0.0, 1.0, fract(yIdx)));
            smoke = max(smoke - 0.475, 0.0);
    return smoke * smoke * 10.0;
}

void computeNetherSmoke3_7(inout vec3 vl, in vec3 translucent, in float dither) {
    float z0 = texture2D(depthtex0, texCoord).r;
    float z1 = texture2D(depthtex1, texCoord).r;

    //Total visibility
    float visibility = int(z0 > 0.56) * float(isEyeInWater == 0);

    #if MC_VERSION >= 11900
    visibility *= 1.0 - darknessFactor;
    #endif

    visibility *= 1.0 - blindFactor;

    if (visibility > 0.0) {
        float linearDepth0 = getLinearDepth2(z0);
        float linearDepth1 = getLinearDepth2(z1);

        //Ray direction (view -> world, normalized so z maps to -1 for depth sampling)
        vec3 viewPos = ToView(vec3(texCoord.xy, z1));
        vec3 nViewPos = normalize(viewPos);
        vec3 nWorldPos = normalize(ToWorld(viewPos));
             nWorldPos /= -nViewPos.z;

        float maxDist = 128.0;
        float maxCurrentDist = min(linearDepth1, maxDist);

        //3.7 smoke color (3.7's netherColSqrt^4 = fogColor^0.5)
        vec3 smokeCol = pow(normalize(fogColor + 0.00000001), vec3(0.5));

        //Smoke animation wind (3.7)
        vec3 wind2 = vec3(-sin(frameTimeCounter * 0.3) * 0.2, -4.0 * frameTimeCounter, cos(frameTimeCounter * 0.5) * 0.4);

        //Ray march (exponential sampling like 3.7)
        float currentDist = exp2(dither);
        int sampleCount = 8;

        for (int i = 0; i < sampleCount; i++, currentDist *= 2.0) {
            if (currentDist > maxCurrentDist || linearDepth1 < currentDist) break;

            vec3 sampleWorldPos = nWorldPos * currentDist;
            float lWorldPos = length(sampleWorldPos);
            if (lWorldPos > maxDist) break;

            vec3 rayPos = sampleWorldPos + cameraPosition;

            //Nether smoke
            if (lWorldPos < 128.0 && rayPos.y > 40.0 && rayPos.y < 255.0) {
                float fogSample = getNetherFogSample3_7(rayPos * NETHER_SMOKE_3_7_FREQUENCY + wind2 * NETHER_SMOKE_3_7_SPEED);
                float fade = clamp(rayPos.y / 40.0, 0.0, 1.0) * (1.0 - clamp(rayPos.y / 255.0, 0.0, 1.0));

                float currentSampleIntensity = (currentDist / maxDist) / float(sampleCount);
                vec3 smokeSample = smokeCol * fogSample * (1.0 + fogSample) * 16.0 * fade;

                //Translucency blending
                if (linearDepth0 < currentDist) {
                    smokeSample *= translucent;
                }

                vl += smokeSample * currentSampleIntensity * NETHER_SMOKE_3_7_STRENGTH;
            }
        }
        vl *= visibility;
    }
}
#endif
