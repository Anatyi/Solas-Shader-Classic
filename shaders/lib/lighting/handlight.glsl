//Per-handheld-light-source strength multiplier (independent from blocklight colors)
float getHandlightStrength(int id) {
    if (id == 5) return HL_TLCF_I;
    else if (id == 6) return HL_SOUL_I;
    else if (id == 7) return HL_ER_I;
    else if (id == 8) return HL_SL_I;
    else if (id == 9) return HL_GS_I;
    else if (id == 10) return HL_SLRL_I;
    else if (id == 72 || id == 73) return HL_CTL_I;
    else if (id == 29) return HL_RED_I;
    else if (id == 12) return HL_LAVA_I;
    else if (id == 41) return HL_JL_I;
    else if (id == 32 || id == 33 || id == 34) return HL_FROG_I;
    else if (id == 60) return HL_BC_I;
    return 1.0;
}

void getHandLightColor(inout vec3 blockLighting, float lViewPos) {
	float heldLightValue = max(float(heldBlockLightValue), float(heldBlockLightValue2));
	float handlight = clamp((heldLightValue - 2.0 * lViewPos) * 0.025, 0.0, 1.0);

    vec3 handLightColor = blockLightCol;

    if (handlight > 0.0) {
        if (heldItemId2 < 3) {
            handLightColor = getBlocklightColor(heldItemId);
            handLightColor *= getHandlightStrength(heldItemId);
        } else {
            handLightColor = getBlocklightColor(heldItemId2);
            handLightColor *= getHandlightStrength(heldItemId2);
        }
    }

    blockLighting += mix(handLightColor * handlight * DYNAMIC_HANDLIGHT_STRENGTH, vec3(0.0), vec3(1.0 - handlight));
}