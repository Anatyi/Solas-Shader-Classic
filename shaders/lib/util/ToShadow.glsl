vec3 ToShadow(vec3 worldPos) {
    #if defined PORT_END_ON && defined END
    //Rotate the shadow sampling with the revolving End black hole so ground shadows follow it (End only)
    float enhEndTF = fract(frameTimeCounter * ((1.0 / 60.0) / ENH_END_REVOLUTION_CYCLE) + ENH_END_START_ANGLE / 360.0) * TAU;
    float enhEndC = cos(-enhEndTF);
    float enhEndS = sin(-enhEndTF);
    worldPos = vec3(worldPos.x * enhEndC - worldPos.z * enhEndS, worldPos.y, worldPos.x * enhEndS + worldPos.z * enhEndC);
    #endif
    vec3 shadowPos = mat3(shadowModelView) * worldPos + shadowModelView[3].xyz;
		 shadowPos = projMAD(shadowProjection, shadowPos);
    float distb = sqrt(shadowPos.x * shadowPos.x + shadowPos.y * shadowPos.y);
    float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);

    shadowPos.xy /= distortFactor;
    shadowPos.z *= 0.2;
    shadowPos = shadowPos * 0.5 + 0.5;
    shadowPos.z += 0.0512 / shadowMapResolution;
    
    return shadowPos;
}