//Copper Torches & Lanterns (emissive core detection)
if (material == 72 || material == 73) {
    float NoU = clamp(dot(normal, upVec), -1.0, 1.0);
    emission = float(albedo.r - albedo.b < 0.1 && albedo.g > 0.5 && material == 72);
    emission += float(albedo.r - albedo.b < 0.1 && albedo.b * 1.1 - albedo.g - albedo.r < -0.45 && albedo.g > 0.5 && material == 73) * float(NoU > -0.5 && NoU < 0.5);
}
