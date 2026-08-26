//Settings//
#include "/lib/common.glsl"

#define DEFERRED

#ifdef FSH

//Varyings//
in vec2 texCoord;

#if defined OVERWORLD || defined END
in vec3 sunVec, upVec;
#endif

//Uniforms//
uniform int isEyeInWater;
uniform int frameCounter;

#if defined AURORA_3_7 || defined VC_3_7 || defined STARS_3_7
uniform int worldDay;
#endif

#ifdef OVERWORLD
uniform int moonPhase;

uniform float timeBrightness, timeAngle, rainStrength, wetness;
uniform float isSnowy;
#endif

#if MC_VERSION >= 11900
uniform float darknessFactor;
#endif

uniform float far, near;
uniform float blindFactor;
uniform float frameTimeCounter;
uniform float viewWidth, viewHeight;
uniform float shadowFade;

#ifdef OVERWORLD
uniform ivec2 eyeBrightnessSmooth;

uniform vec3 skyColor;
#endif

uniform vec3 fogColor;
uniform vec3 cameraPosition;

#ifdef MILKY_WAY
uniform sampler2D depthtex2;
#endif

#if defined SKYBOX || defined VANILLA_SUN_MOON
uniform sampler2D colortex7;
uniform sampler2D colortex6;
#endif

uniform sampler2D noisetex;
#if defined VC_3_7 || defined AURORA_3_7 || defined GENERATED_NIGHT_NEBULA || defined PLANAR_CLOUDS_3_7
uniform sampler2D noise3_7;
#endif
uniform sampler2D colortex0;
uniform sampler2D depthtex1;

#ifdef DISTANT_HORIZONS
uniform float dhFarPlane, dhNearPlane;

uniform sampler2D dhDepthTex0;
#endif

#if defined VC || defined END_CLOUDY_FOG || defined VC_3_7 || defined END_DISK_3_7
uniform sampler2D shadowtex1;

#ifdef BLOCKY_CLOUDS
uniform sampler2D shadowcolor1;
#endif

uniform mat4 shadowModelView, shadowProjection;
#endif

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

#ifdef DISTANT_HORIZONS
uniform mat4 dhProjectionInverse;
#endif

#ifdef OVERWORLD
uniform mat4 gbufferModelView;
#endif

//Common Variables//
#ifdef OVERWORLD
float eBS = eyeBrightnessSmooth.y / 240.0;
float caveFactor = mix(clamp((cameraPosition.y - 56.0) / 16.0, float(sign(isEyeInWater)), 1.0), 1.0, eBS);
float sunVisibility = clamp(dot(sunVec, upVec) + 0.1, 0.0, 0.25) * 4.0;
#if defined AURORA_3_7 || defined VC_3_7 || defined SKY_3_7 || defined SUN_MOON_3_7 || defined STARS_3_7 || defined PLANAR_CLOUDS_3_7
//3.7 moon visibility saturates right at the horizon (moon up = 1.0), so moonlight keeps lighting
//the sky/nebula evenly (3.7 moon glow tint). The 2.3 formula needs the moon higher to reach 1.0.
float moonVisibility = clamp(dot(-sunVec, upVec) + 0.0625, 0.0, 0.125) / 0.125;
#endif
#endif

//Includes//
#include "/lib/util/bayerDithering.glsl"
#include "/lib/util/ToView.glsl"
#include "/lib/util/ToWorld.glsl"
#include "/lib/color/lightColor.glsl"
#include "/lib/color/netherColor.glsl"

#ifdef OVERWORLD
#include "/lib/atmosphere/sky.glsl"
#ifdef SKY_3_7
#include "/lib/atmosphere/sky3_7.glsl"
#endif
#include "/lib/atmosphere/sunMoon.glsl"
#endif

#if defined VC || defined END_CLOUDY_FOG || defined VC_3_7 || defined END_DISK_3_7
#include "/lib/atmosphere/spaceConversion.glsl"
#include "/lib/util/ToShadow.glsl"
#endif

#ifdef VC
#ifndef BLOCKY_CLOUDS
#include "/lib/atmosphere/volumetricClouds.glsl"
#else
#include "/lib/atmosphere/volumetricBlockyClouds.glsl"
#endif
#endif

#ifdef VC_3_7
#include "/lib/atmosphere/volumetricClouds3_7.glsl"
#endif

#ifdef END_CLOUDY_FOG
#include "/lib/atmosphere/volumetricClouds.glsl"
#endif

#ifdef END_DISK_3_7
#include "/lib/atmosphere/endDisk3_7.glsl"
#endif

#ifdef AURORA_3_7
#include "/lib/atmosphere/aurora.glsl"
#endif

#if defined STARS_3_7 || defined END_STARS_3_7
#include "/lib/atmosphere/stars3_7.glsl"
#endif

#ifdef PLANAR_CLOUDS_3_7
#include "/lib/atmosphere/planarClouds3_7.glsl"
#endif

#if defined END_NEBULA_3_7 || defined END_BLACK_HOLE_3_7
#include "/lib/atmosphere/endNebula3_7.glsl"
#endif

#include "/lib/atmosphere/skyEffects.glsl"
#include "/lib/atmosphere/fog.glsl"

void main() {
	vec3 color = texture2D(colortex0, texCoord).rgb;

	float z1 = texture2D(depthtex1, texCoord).r;

	#ifdef DISTANT_HORIZONS
	float dhZ = texture2D(dhDepthTex0, texCoord).r;
	#endif

	vec3 viewPos = ToView(vec3(texCoord, z1));
	vec3 worldPos = ToWorld(viewPos);

    //Atmosphere
	#if defined OVERWORLD
	vec3 sunPos = vec3(gbufferModelViewInverse * vec4(sunVec * 128.0, 1.0));
	vec3 sunCoord = sunPos / (sunPos.y + length(sunPos.xz));
	#ifdef SKY_3_7
	float atmosphereHardMixFactor = 0.0;
	vec3 atmosphereColor = getAtmosphere3_7(viewPos, worldPos, atmosphereHardMixFactor);
	#else
    vec3 atmosphereColor = getAtmosphericScattering(viewPos, normalize(sunCoord));
	#endif

	#ifdef SKYBOX
	vec3 skybox = texture2D(colortex7, texCoord).rgb;
	if (length(pow(skybox, vec3(0.1))) > 0.0) atmosphereColor = mix(atmosphereColor, skybox, SKYBOX_MIX_FACTOR);
	#endif
	#elif defined NETHER
	vec3 atmosphereColor = netherColSqrt.rgb * 0.25;
	#elif defined END
	#if defined END_NEBULA_3_7 || defined END_BLACK_HOLE_3_7
	//3.7 End sky base (ambient color) so the 3.7 nebula blends like in 3.7 instead of sitting on
	//the darker 2.3 light-color base.
	vec3 atmosphereColor = endAmbientColSqrt * 0.175;
	#else
	vec3 atmosphereColor = endLightCol * 0.1;
	#endif
	#endif

    vec3 skyColor = atmosphereColor;
	vec3 skyColorO = atmosphereColor;

	#if defined OVERWORLD || defined END
	vec3 nViewPos = normalize(viewPos);

	float VoU = dot(nViewPos, upVec);
	float VoS = clamp(dot(nViewPos, sunVec), 0.0, 1.0);
	float VoM = clamp(dot(nViewPos, -sunVec), 0.0, 1.0);
	#endif

    //Volumetric clouds
	vec4 vc = vec4(0.0);
	#ifdef VC_3_7
	vec4 vc37 = vec4(0.0);
	#endif
	float cloudAuroraRaw = 0.0; //blocky cloud alpha WITHOUT the distance fade, for aurora culling

	#ifdef DISTANT_HORIZONS
	float cloudDepth = 2.0 * dhFarPlane;
	#else
	float cloudDepth = 2.0 * far;
	#endif

	#ifdef VC_3_7
	//3.7 volumetric clouds (independent of the 2.3 VC switch, so both can be on or off together)
	float blueNoiseDither37 = texture2D(noisetex, gl_FragCoord.xy / 512.0).b;
	#ifdef TAA
	blueNoiseDither37 = fract(blueNoiseDither37 + 1.61803398875 * mod(float(frameCounter), 3600.0));
	#endif
	float cloudDepth37 = cloudDepth;
	computeVolumetricClouds3_7(vc37, atmosphereColor, z1, blueNoiseDither37, cloudDepth37);
	vc37.rgb = pow(vc37.rgb, vec3(1.0 / 2.2));
	#endif
	
	#ifdef VC
	float blueNoiseDither = texture2D(noisetex, gl_FragCoord.xy / 512.0).b;

	#ifdef TAA
	blueNoiseDither = fract(blueNoiseDither + 1.61803398875 * mod(float(frameCounter), 3600.0));
	#endif

	#ifdef BLOCKY_CLOUDS
	computeVolumetricClouds(vc, atmosphereColor, z1, blueNoiseDither, cloudDepth, cloudAuroraRaw);
	#else
	computeVolumetricClouds(vc, atmosphereColor, z1, blueNoiseDither, cloudDepth);
	#endif
	vc.rgb = pow(vc.rgb, vec3(1.0 / 2.2));
	#endif

	//Combined cloud occlusion alpha (2.3 VC and/or 3.7 clouds both occlude sky elements)
	#ifdef VC_3_7
	#ifdef VC
	float vcCombinedAlpha = min(vc.a + vc37.a, 1.0);
	#else
	float vcCombinedAlpha = vc37.a;
	#endif
	#else
	float vcCombinedAlpha = vc.a;
	#endif

	//Blocky clouds cull the aurora behind them (BLOCKY_CLOUDS_AURORA_OCCLUSION switch + strength).
	//The mask uses the distance-fade-free cloud alpha (cloudAuroraRaw) so far clouds also cull the
	//aurora behind them, then scales it up so semi-transparent clouds fully hide the aurora
	//(otherwise far/highlighted aurora keeps shining through). strength 0 = vanilla linear fade,
	//1 = full culling (cloud alpha >= 0.5 hides the aurora completely).
	float auroraCloudMask = vcCombinedAlpha;
	#ifdef BLOCKY_CLOUDS_AURORA_OCCLUSION
	auroraCloudMask = clamp(cloudAuroraRaw * (1.0 + BLOCKY_CLOUDS_AURORA_OCCLUSION_STRENGTH), 0.0, 1.0);
	#endif

	#if defined END_CLOUDY_FOG
	float blueNoiseDither = texture2D(noisetex, gl_FragCoord.xy / 512.0).b;

	#ifdef TAA
	blueNoiseDither = fract(blueNoiseDither + 1.61803398875 * mod(float(frameCounter), 3600.0));
	#endif

	computeEndVolumetricClouds(vc, atmosphereColor, z1, blueNoiseDither, cloudDepth);
	vc.rgb = pow(vc.rgb, vec3(1.0 / 2.2));
	#endif

	#ifdef END_DISK_3_7
	//3.7 End Disk (Ender Protoplanetary Disk) - independent buffer so it can stack with the 2.3
	//End cloudy fog (both controls may be on at once: the fog fills the band, the disk adds its
	//own rotating cloud layer). Keeps the closest cloud depth so glass is culled by either layer.
	vec4 vcEndDisk = vec4(0.0);
	float blueNoiseDither37 = texture2D(noisetex, gl_FragCoord.xy / 512.0).b;

	#ifdef TAA
	blueNoiseDither37 = fract(blueNoiseDither37 + 1.61803398875 * mod(float(frameCounter), 3600.0));
	#endif

	#ifdef DISTANT_HORIZONS
	float cloudDepthDisk = 2.0 * dhFarPlane;
	#else
	float cloudDepthDisk = 2.0 * far;
	#endif

	computeEndDisk3_7(vcEndDisk, atmosphereColor, z1, blueNoiseDither37, cloudDepthDisk);
	vcEndDisk.rgb = pow(vcEndDisk.rgb, vec3(1.0 / 2.2));

	//Stack the disk over the 2.3 fog; keep the closest cloud depth for glass culling
	#if defined END_CLOUDY_FOG
	vc = vec4(mix(vc.rgb, vcEndDisk.rgb, vcEndDisk.a), max(vc.a, vcEndDisk.a));
	cloudDepth = min(cloudDepth, cloudDepthDisk);
	#else
	vc = vcEndDisk;
	cloudDepth = cloudDepthDisk;
	#endif
	#endif

	//Atmosphere & Fog
	float auroraOcclusion = 0.0;
	float nebulaFactor = 0.0;

	#if defined AURORA_3_7 && defined OVERWORLD
	//3.7 volumetric aurora: ray-marched world-locked volume, driven by kpIndex geomagnetic activity
	#ifdef VC_3_7
	float occlusion = pow4(vc.a + vc37.a);
	#else
	float occlusion = pow4(vc.a);
	#endif
	#ifdef BLOCKY_CLOUDS_AURORA_OCCLUSION
	//Linear (not pow4, which weakens semi-transparent clouds so far/highlighted aurora leaks through)
	occlusion = max(occlusion, auroraCloudMask); //blocky clouds cull the aurora behind them
	#endif
	vec3 aurora = vec3(0.0);
	float auroraDither = texture2D(noisetex, gl_FragCoord.xy / 512.0).b;
	#ifdef TAA
	auroraDither = fract(auroraDither + 1.61803398875 * mod(float(frameCounter), 3600.0));
	#endif
	computeVolumetricAurora(aurora, z1, auroraDither, caveFactor, occlusion, auroraOcclusion);
	#endif

	#if defined END_NEBULA && !defined END_NEBULA_3_7
	getEndNebula(skyColor, worldPos, VoU, nebulaFactor, 1.0);
	#endif

	#if defined END_NEBULA_3_7 || defined END_BLACK_HOLE_3_7
	drawEndNebula3_7(skyColor, worldPos, VoU, VoS);
	#endif

	vec3 stars = vec3(0.0);
	float pc = 0.0;

	#ifdef OVERWORLD
	if (VoU > 0.0) {
		#if defined MILKY_WAY || defined MILKY_WAY_3_7
		drawMilkyWay(skyColor, worldPos, VoU, caveFactor, nebulaFactor, vcCombinedAlpha * 2.0, auroraOcclusion);
		#endif

		#if defined AURORA && !defined AURORA_3_7
		drawAurora(skyColor, worldPos, VoU, caveFactor, auroraCloudMask);
		#endif

		#if defined PLANAR_CLOUDS && defined PLANAR_CLOUDS_3_7
		drawPlanarClouds3_7(skyColor, atmosphereColor, worldPos, viewPos, VoU, caveFactor, vcCombinedAlpha, pc);
		#elif defined PLANAR_CLOUDS
		drawPlanarClouds(skyColor, atmosphereColor, worldPos, viewPos, VoU, caveFactor, vcCombinedAlpha, pc);
		#endif

		#ifdef STARS
		#endif

		#if defined STARS && defined STARS_3_7
		drawStars3_7(skyColor, worldPos, VoU, caveFactor, nebulaFactor, min(vcCombinedAlpha * 2.0 + pow(pc, 0.25), 1.0), STAR_SIZE);
		#ifdef SHOOTING_STARS
		getShootingStars(skyColor, worldPos, VoU);
		#endif
		#elif defined STARS
		drawStars(skyColor, worldPos, stars, VoU, caveFactor, nebulaFactor, min(vcCombinedAlpha * 2.0 + pow(pc, 0.25), 1.0), 0.4, 1.0, 0.0, 1.0);
		#endif

		#ifdef RAINBOW
		getRainbow(skyColor, worldPos, VoU, 1.75, 0.05, caveFactor);
		#endif
	}

	#ifdef SUN_MOON_3_7
	//3.7 sun/moon: occlusion = cloud cover (pow4 like 3.7's pow4(vc.a)), keeps the disc hidden by clouds
	float sunMoonOcclusion = pow4(vcCombinedAlpha);
	drawSunMoon3_7(skyColor, worldPos, nViewPos, VoU, VoS, VoM, caveFactor, sunMoonOcclusion);
	#else
	getSunMoon(skyColor, nViewPos, worldPos, lightSun, lightNight, VoS, VoM, VoU, caveFactor * (1.0 - vcCombinedAlpha) * (1.0 - pc));
	#endif

	#ifdef VANILLA_SUN_MOON
	//The sun/moon disc is carried in colortex6 (written by gbuffers_skytextured, cleared each
	//frame) - no residual content, so it cannot accumulate or add retained sky over the scene.
	float sunMoonVis = (1.0 - rainStrength) * caveFactor * (1.0 - vcCombinedAlpha) * (1.0 - pc) * clamp(VoU, 0.0, 1.0);
	skyColor += texture2D(colortex6, texCoord).rgb * sunMoonVis;
	#endif
	#endif

	#ifdef END
	#if defined END_BLACK_HOLE_3_7 || defined END_VORTEX_LENS
	//Black hole gravitational vortex: dim stars around the hole and push them outward into a ring.
	//The 3.7 black hole uses its size control; the 2.3 vortex (END_VORTEX_LENS) uses a fixed size 1.0.
	float bhLensSize = 1.0;
	#ifdef END_BLACK_HOLE_3_7
	bhLensSize = END_BLACK_HOLE_SIZE_3_7;
	#endif
	float bhHoleDim = 1.0 - pow(pow(pow32(VoS), bhLensSize), 2.0);
	float bhLensRing = pow(pow4(pow32(VoS)), bhLensSize);
	#else
	float bhLensSize = 1.0;
	float bhHoleDim = 1.0;
	float bhLensRing = 0.0;
	#endif
	#ifdef END_STARS_3_7
	//3.7 ender starfield (constellation-like star clusters) - can coexist with the 2.3 End stars.
	//Applies the same gravitational lensing/vortex shear as the 2.3 stars (3.7 hole or 2.3 vortex).
	drawEndStars3_7(skyColor, worldPos, nebulaFactor, VoS, bhHoleDim, bhLensRing, bhLensSize);
	#endif
	#ifdef END_STARS
	#ifdef PORT_END_LENS_ON
	//Gravitational lensing: warp nearby stars around the black hole
	drawStars(skyColor, enhEndLensWarp(worldPos, sunVec), stars, VoU, 1.0, nebulaFactor, vc.a, 0.3, bhHoleDim, bhLensRing, bhLensSize);
	#else
	drawStars(skyColor, worldPos, stars, VoU, 1.0, nebulaFactor, vc.a, 0.3, bhHoleDim, bhLensRing, bhLensSize);
	#endif
	#endif

	#if defined END_VORTEX && !defined END_BLACK_HOLE_3_7
	getEndVortex(skyColor, worldPos, stars, VoU, VoS);
	#endif
	#endif

	skyColor *= 1.0 + (Bayer8(gl_FragCoord.xy) - 0.5) / 32.0;

	#if MC_VERSION >= 11900
	skyColor *= 1.0 - darknessFactor;
	#endif

	skyColor *= 1.0 - blindFactor;

	if (z1 < 1.0) {
		Fog(color, viewPos, worldPos, skyColorO);

	#ifdef DISTANT_HORIZONS
	} else if (dhZ < 1.0) {
		vec4 dhScreenPos = vec4(texCoord, dhZ, 1.0);
		vec4 dhViewPos = dhProjectionInverse * (dhScreenPos * 2.0 - 1.0);
			 dhViewPos /= dhViewPos.w;
		
		Fog(color, dhViewPos.xyz, ToWorld(dhViewPos.xyz), skyColorO);
	#endif

	} else {
		color = skyColor;
	}

	//Aurora 3.7 (volumetric, added to the final color like 3.7 so it reads as a depth volume behind clouds)
	#if defined AURORA_3_7 && defined OVERWORLD
	//3.7 uses AURORA_BRIGHTNESS 0.5 (the 2.3 default is 0.7) and a darker tonemap, so the same volume
	//here reads as a blown-out white core. EXPOSURE/CONTRAST are debug controls; SOFTEN rolls off the
	//highlights so it keeps its colour bands instead of clipping to white.
	vec3 auroraOut = aurora * (0.5 / 0.7) * AURORA_EXPOSURE;      //Debug: exposure (brightness)
	auroraOut = pow(auroraOut, vec3(AURORA_CONTRAST));             //Debug: contrast
	auroraOut /= 1.0 + auroraOut * (AURORA_SOFTEN * 0.5);          //highlight roll-off
	color += auroraOut;
	#endif

	#if defined VC || defined VC_3_7 || defined END_CLOUDY_FOG || defined END_DISK_3_7
	#ifdef DISTANT_HORIZONS
	cloudDepth /= (2.0 * dhFarPlane);
	#else
	cloudDepth /= (2.0 * far);
	#endif

	//End fog/clouds composite through the same vc buffer (restored from 2.3.1: the mix was
	//previously gated only by VC, so END_CLOUDY_FOG's vc never reached the final color).
	#if defined VC || defined END_CLOUDY_FOG || defined END_DISK_3_7
	color = mix(color, vc.rgb, vc.a);
	#endif
	#ifdef VC_3_7
	//3.7 clouds composite over the 2.3 clouds/sky so they can be stacked independently
	color = mix(color, vc37.rgb, vc37.a);
	#endif
	#endif

	/* DRAWBUFFERS:064 */
	gl_FragData[0].rgb = color;
    gl_FragData[1] = vec4(pow(color.rgb, vec3(0.125)) * 0.5, 1.0);
	gl_FragData[2].g = cloudDepth;
}

#endif

/////////////////////////////////////////////////////////////////////////////////////

#ifdef VSH

//Varyings//
out vec2 texCoord;

#if defined OVERWORLD || defined END
out vec3 sunVec, upVec;
#endif

//Uniforms
#if defined OVERWORLD || defined END
uniform float timeAngle;

uniform mat4 gbufferModelView;
#endif

void main() {
	//Coords
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
	
	//Sun & Other vectors
    #if defined OVERWORLD || defined END
	sunVec = getSunVector(gbufferModelView, timeAngle);
	upVec = normalize(gbufferModelView[1].xyz);
	#endif

	//Position
	gl_Position = ftransform();
}

#endif