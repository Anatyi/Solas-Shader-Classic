//Settings//
#include "/lib/common.glsl"

#ifdef FSH

//Varyings//
in vec2 texCoord;

//Uniforms//
#if defined BLOOM || defined LENS_FLARE_ANY || defined DOF
#if defined TAA && !defined PORT_END_ON
uniform int frameTimeCounter;
#elif defined PORT_END_ON
uniform float frameTimeCounter;
#endif

uniform float viewWidth, viewHeight;
uniform float aspectRatio;

#ifdef OVERWORLD
uniform float timeBrightness;
#endif
#endif

#ifdef LENS_FLARE_ANY
uniform int isEyeInWater;
uniform float wetness;
uniform float blindFactor;
#if MC_VERSION >= 11900
uniform float darknessFactor;
#endif
uniform vec3 cameraPosition, sunPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
#ifdef OVERWORLD
uniform float shadowFade;
#endif
#endif

#if defined BLOOM && defined AURORA_3_7 && defined OVERWORLD && !defined LENS_FLARE_ANY
uniform vec3 cameraPosition, sunPosition;
uniform mat4 gbufferModelView;
#endif

#if defined LENS_FLARE_ANY || defined DOF
uniform mat4 gbufferProjection;
uniform sampler2D depthtex1;
#endif

#ifdef DOF
#ifndef MANUAL_FOCUS
uniform float centerDepthSmooth;
#else
uniform float far, near;
float centerDepthSmooth = ((DOF_FOCUS - near) * far) / ((far - near) * DOF_FOCUS);
#endif
#endif

uniform ivec2 eyeBrightnessSmooth;

uniform sampler2D colortex0;
uniform sampler2D colortex2;

#ifdef BLOOM
uniform sampler2D colortex1;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
#endif

//Optifine Constants//
const bool colortex0MipmapEnabled = true;

#ifdef TAA
const bool colortex2Clear = false;
const bool colortex2MipmapEnabled = true;
#endif

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;

#ifdef LENS_FLARE_ANY
#if defined PORT_END_ON && defined END
//Revolve the End black hole direction for the lens flare (called at sunVec initialisation - no global re-assignment)
vec3 enhEndRevolveDir() {
	vec3 enhWorldSun = mat3(gbufferModelViewInverse) * sunPosition;
	float enhEndTF = fract(frameTimeCounter * ((1.0 / 60.0) / ENH_END_REVOLUTION_CYCLE) + ENH_END_START_ANGLE / 360.0) * TAU;
	float enhEndC = cos(enhEndTF);
	float enhEndS = sin(enhEndTF);
	vec3 enhRotated = vec3(enhWorldSun.x * enhEndC - enhWorldSun.z * enhEndS, enhWorldSun.y, enhWorldSun.x * enhEndS + enhWorldSun.z * enhEndC);
	return normalize(mat3(gbufferModelView) * enhRotated);
}
vec3 sunVec = enhEndRevolveDir();
#else
vec3 sunVec = normalize(sunPosition);
#endif
vec3 upVec = normalize(gbufferModelView[1].xyz);
float caveFactor = mix(clamp((cameraPosition.y - 56.0) / 16.0, float(sign(isEyeInWater)), 1.0), 1.0, sqrt(eBS));
float sunVisibility = clamp((dot( sunVec, upVec) + 0.15) * 3.0, 0.0, 1.0);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.15) * 3.0, 0.0, 1.0);
#endif

#if defined BLOOM && defined AURORA_3_7 && defined OVERWORLD && !defined LENS_FLARE_ANY
vec3 sunVec = normalize(sunPosition);
vec3 upVec = normalize(gbufferModelView[1].xyz);
float moonVisibility = clamp((dot(-sunVec, upVec) + 0.15) * 3.0, 0.0, 1.0);
#endif

//Includes//
#include "/lib/util/bayerDithering.glsl"
#include "/lib/post/tonemap.glsl"

#ifdef BLOOM
#include "/lib/post/getBloom.glsl"
#endif

#ifdef DOF
#include "/lib/util/ToView.glsl"
#include "/lib/post/computeDOF.glsl"
#endif

#ifdef LENS_FLARE_ANY
#include "/lib/post/lensFlare.glsl"
#endif

//Program//
void main() {
	vec3 color = texture2D(colortex0, texCoord).rgb;

	#ifdef TAA
	vec3 temporalColor = texture2DLod(colortex2, texCoord, 0).gba;
	#endif

	float temporalData = 0.0;

	#ifdef LENS_FLARE_ANY
	float pixelWidth = 1.0 / viewWidth;
	float pixelHeight = 1.0 / viewHeight;
	float tempVisibleSun = texture2D(colortex2, vec2(3.0 * pixelWidth, pixelHeight)).r;
	#endif

	#ifdef DOF
	float z1 = texture2D(depthtex1, texCoord).r;
	color = getDepthOfField(color, texCoord, z1);
	#endif

	#ifdef BLOOM
    float z0 = texture2D(depthtex0, texCoord).r;
	getBloom(color, texCoord, z0);
	#endif

	color = Uncharted2Tonemap(color * TONEMAP_BRIGHTNESS) / Uncharted2Tonemap(vec3(TONEMAP_WHITE_THRESHOLD));
	color = pow(color, vec3(1.0 / 2.2));
	colorSaturation(color);
	color += (Bayer8(gl_FragCoord.xy) - 0.25) / 64.0;

	//Lens Flare
	#ifdef LENS_FLARE_ANY
	vec2 lightPos = getLightPos();
	float truePos = sign(sunVec.z);

	float visibleSun = float(texture2D(depthtex1, lightPos + 0.5).r >= 1.0);
		  visibleSun *= max(1.0 - isEyeInWater, eBS) * (1.0 - wetness) * caveFactor;

	#if MC_VERSION >= 11900
		  visibleSun *= (1.0 - max(blindFactor, darknessFactor));
	#endif

	//Per-dimension lens flare: independent switch / strength / style (default off in the Nether)
	float multiplier = tempVisibleSun * (length(color) * 0.25 + 0.25);

	float flareStrength = 0.0;
	int flareStyle = 0;

	#ifdef OVERWORLD
	#ifdef LENS_FLARE
	flareStrength = LENS_FLARE_STRENGTH * shadowFade;
	flareStyle = LENS_FLARE_STYLE;
	#endif
	#endif

	#ifdef END
	#ifdef END_LENS_FLARE
	flareStrength = END_LENS_FLARE_STRENGTH;
	flareStyle = END_LENS_FLARE_STYLE;
	#endif
	#endif

	#ifdef NETHER
	#ifdef NETHER_LENS_FLARE
	flareStrength = NETHER_LENS_FLARE_STRENGTH;
	flareStyle = NETHER_LENS_FLARE_STYLE;
	#endif
	#endif

	multiplier *= flareStrength;

	if (multiplier > 0.001) LensFlare(color, lightPos, truePos, multiplier, flareStyle);

	if (texCoord.x > 2.0 * pixelWidth && texCoord.x < 4.0 * pixelWidth && texCoord.y < 2.0 * pixelHeight)
		temporalData = mix(tempVisibleSun, visibleSun, 0.125);
	#endif

	/* DRAWBUFFERS:1 */
	gl_FragData[0].rgb = color;

    #ifdef TAA
    /* DRAWBUFFERS:12 */
	#ifdef LENS_FLARE
	gl_FragData[1] = vec4(temporalData, temporalColor);
	#else
	gl_FragData[1].gba = temporalColor;
	#endif
    #endif
}

#endif

/////////////////////////////////////////////////////////////////////////////////////

#ifdef VSH

//Varyings//
out vec2 texCoord;

//Program//
void main() {
	//Coord
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	//Position
	gl_Position = ftransform();
}

#endif