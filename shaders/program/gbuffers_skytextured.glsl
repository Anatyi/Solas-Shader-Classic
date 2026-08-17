//Settings//
#include "/lib/common.glsl"

#ifdef FSH

//Varyings//
uniform int renderStage;

in vec2 texCoord;
in vec4 color;

uniform sampler2D texture;

//Pipeline Constans//
const bool colortex6Clear = true;
const bool colortex7Clear = false;
const bool gaux4Clear = false;

//Program//
void main() {
	vec4 albedo = texture2D(texture, texCoord) * color;
		 albedo.rgb = pow(albedo.rgb, vec3(2.2)) * albedo.a;
		 albedo.rgb = sqrt(max(albedo.rgb, vec3(0.0)));

	vec3 sunMoon = vec3(0.0);

	#ifdef VANILLA_SUN_MOON
	if (renderStage == MC_RENDER_STAGE_SUN || renderStage == MC_RENDER_STAGE_MOON) {
		//Vanilla sun/moon texture keeps the shape; the shader draws the color (Complementary-style).
		//No rotation/size - the vanilla sprite is shown as-is (rotation/size would tear the sprite).
		vec4 smTex = texture2D(texture, texCoord) * color;
		     smTex.rgb = pow(smTex.rgb, vec3(2.2)) * smTex.a;
		     smTex.rgb = sqrt(max(smTex.rgb, vec3(0.0)));
		float lum = dot(smTex.rgb, vec3(0.299, 0.587, 0.114));
		float smBrightness = (renderStage == MC_RENDER_STAGE_SUN) ? VANILLA_SUN_BRIGHTNESS : VANILLA_MOON_BRIGHTNESS;

		if (renderStage == MC_RENDER_STAGE_SUN) {
			sunMoon = lum * vec3(1.0, 0.8, 0.5) * 2.5;
		} else {
			sunMoon = lum * vec3(0.85, 0.9, 1.0) * 1.5;
		}
		sunMoon *= smTex.a * smBrightness;

		//Hide the sun/moon from the skybox buffer (colortex7) but keep a small alpha so the
		//fragment isn't discarded - the disc is carried to deferred2 via colortex6 instead.
		albedo.rgb *= 0.0;
		albedo.a = 0.01;
	}
	#else
	if (renderStage == MC_RENDER_STAGE_SUN || renderStage == MC_RENDER_STAGE_MOON) {
		albedo *= 0.0;
	}
	#endif

	//colortex6 carries ONLY the sun/moon disc (black sky) so deferred2 can add it without
	//double-rendering the sky. colortex6Clear=true -> cleared each frame, no residual/accumulation.
    /* DRAWBUFFERS:76 */
	gl_FragData[0] = albedo;
	gl_FragData[1] = vec4(sunMoon, 1.0);
}

#endif

/////////////////////////////////////////////////////////////////////////////////////

#ifdef VSH

//Varyings//
out vec2 texCoord;
out vec4 color;

//Program//
void main() {
	//Coord
	texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

	//Color & Position
	color = gl_Color;

	gl_Position = ftransform();
}

#endif