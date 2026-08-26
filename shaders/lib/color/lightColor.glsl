#ifdef OVERWORLD
float timeBrightnessSqrt = sqrt(timeBrightness);
float mefade = 1.0 - clamp(abs(timeAngle - 0.5) * 8.0 - 1.5, 0.0, 1.0);
float dfade = timeBrightness * timeBrightness;

//Sun & Moon Light Color (V3.7 system, defaults preserve V2.3 look)
vec3 lightSunBase = fmix(fmix(fmix(lightSunrise, lightMorning, timeBrightnessSqrt), fmix(lightEvening, lightSunset, 1.0 - timeBrightnessSqrt), mefade), lightDay, dfade);

#ifdef GBUFFERS_TERRAIN
//Preserve V2.3's squared intensity falloff for terrain
vec3 lightSun = lightSunBase * length(lightSunBase);
#else
vec3 lightSun = lightSunBase;
#endif

#ifdef PURPLE_MORNINGS
vec3 lightColRaw = mix(lightNight, lightSun * mix(vec3(1.0, 1.0, 2.0), vec3(1.0), clamp(mefade + timeBrightness, 0.0, 1.0)), sunVisibility * sunVisibility);
#else
vec3 lightColRaw = mix(lightNight, mix(lightSun, normalize(skyColor + 0.0001), 0.1), sunVisibility * sunVisibility);
#endif

vec3 lightColSqrt = mix(lightColRaw, dot(lightColRaw, vec3(0.299, 0.587, 0.114)) * weatherCol, wetness * 0.5);
vec3 lightCol = lightColSqrt * lightColSqrt;

float ambientIntensity = mix(AMBIENTINTENSITY_N, mix(AMBIENTINTENSITY_D * 0.75, AMBIENTINTENSITY_D, timeBrightness), sunVisibility * sunVisibility);
vec3 ambientColor = mix(lightNight, mix(lightColRaw, normalize(skyColor + 0.0001), AMBIENTCOL_SKY_INFLUENCE) * normalize(mix(vec3(1.0), skyColor, AMBIENTCOL_SKY_INFLUENCE) + 0.0001), sunVisibility * sunVisibility);
vec3 ambientColRaw = pow(ambientColor, vec3(0.75)) * 0.5 * ambientIntensity;
vec3 ambientColSqrt = mix(ambientColRaw, dot(ambientColRaw, vec3(0.299, 0.587, 0.114)) * weatherCol, wetness * 0.5);
vec3 ambientCol = ambientColSqrt * ambientColSqrt;

#if defined VC_3_7 || defined SKY_3_7
//3.7 per-biome weather (shared by the 3.7 sky and clouds)
uniform float isDesert, isCherryGrove, isSwamp, isMushroom, isJungle, isLushCaves, isDeepDark;

vec3 biomeColor = vec3(1.105, 0.805, 0.615) * (1.0 + timeBrightness * 0.5) * isDesert +
                  vec3(1.095, 0.925, 1.025) * isCherryGrove +
                  vec3(1.025, 1.285, 0.785) * isSwamp +
                  vec3(1.115, 0.745, 0.975) * isMushroom +
                  vec3(0.955, 1.085, 0.895) * isJungle;
float isSpecificBiome = isDesert + isCherryGrove + isSwamp + isMushroom + isJungle;
vec3 caveBiomeColor = vec3(0.125, 0.145, 0.035) * isLushCaves + vec3(0.025, 0.095, 0.135) * isDeepDark;
float isCaveBiome = isLushCaves + isDeepDark;
#endif
#endif