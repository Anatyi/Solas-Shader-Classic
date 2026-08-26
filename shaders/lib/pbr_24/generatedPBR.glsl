void generateIPBR(inout vec4 albedo, in vec3 worldPos, in vec3 viewPos, inout vec2 lightmap, inout float emission, inout float smoothness2, inout float metalness, inout float subsurface) {
    int material = max(mat - 10000, 0);
    int material2 = max(mat - 20000, 0);
    float lAlbedo = clamp(length(albedo.rgb), 0.0, 1.0);
    float smoothness = 0.0;

    #include "/lib/pbr_24/blocks/amethyst_block.glsl"
    #include "/lib/pbr_24/blocks/amethyst.glsl"
    #include "/lib/pbr_24/blocks/beacon.glsl"
    #include "/lib/pbr_24/blocks/black_materials.glsl"
    #include "/lib/pbr_24/blocks/brewing_stand.glsl"
    #include "/lib/pbr_24/blocks/bricks.glsl"
    #include "/lib/pbr_24/blocks/calcite.glsl"
    #include "/lib/pbr_24/blocks/candles_corals.glsl"
    #include "/lib/pbr_24/blocks/cave_berries.glsl"
    #include "/lib/pbr_24/blocks/concrete.glsl"
    #include "/lib/pbr_24/blocks/creaking_heart.glsl"
    #include "/lib/pbr_24/blocks/dark_materials.glsl"
    #include "/lib/pbr_24/blocks/enchanting_table.glsl"
    #include "/lib/pbr_24/blocks/end_portal_frame.glsl"
    #include "/lib/pbr_24/blocks/end_stone.glsl"
    #include "/lib/pbr_24/blocks/froglights.glsl"
    #include "/lib/pbr_24/blocks/full_emitters.glsl"
    #include "/lib/pbr_24/blocks/glow_lichen_sea_pickle.glsl"
    #include "/lib/pbr_24/blocks/jack_o_lantern.glsl"
    #include "/lib/pbr_24/blocks/magma_block.glsl"
    #include "/lib/pbr_24/blocks/nether_logs.glsl"
    #include "/lib/pbr_24/blocks/nether_plants.glsl"
    #include "/lib/pbr_24/blocks/planks.glsl"
    #include "/lib/pbr_24/blocks/polished_materials.glsl"
    #include "/lib/pbr_24/blocks/powered_rail.glsl"
    #include "/lib/pbr_24/blocks/prismarine.glsl"
    #include "/lib/pbr_24/blocks/purpur.glsl"
    #include "/lib/pbr_24/blocks/quartz.glsl"
    #include "/lib/pbr_24/blocks/redstone_lamp.glsl"
    #include "/lib/pbr_24/blocks/redstone_ore.glsl"
    #include "/lib/pbr_24/blocks/reflective_materials.glsl"
    #include "/lib/pbr_24/blocks/sand.glsl"
    #include "/lib/pbr_24/blocks/sculk.glsl"
    #include "/lib/pbr_24/blocks/soul_emitters.glsl"
    #include "/lib/pbr_24/blocks/spawner.glsl"
    #include "/lib/pbr_24/blocks/terracotta.glsl"
    #include "/lib/pbr_24/blocks/torch_lantern.glsl"
    #include "/lib/pbr_24/blocks/water_cauldron.glsl"
    #include "/lib/pbr_24/blocks/wet_farmland.glsl"

    #ifdef EMISSIVE_FLOWERS
    #include "/lib/pbr_24/blocks/flowers.glsl"
    #endif

    #ifdef EMISSIVE_ORES
    #include "/lib/pbr_24/blocks/ores.glsl"
    #endif

    #ifdef GENERATED_EMISSION
    emission = clamp(emission * EMISSION_STRENGTH, 0.0, 8.0);
    #else
    emission = 0.0;
    #endif

    #ifdef GENERATED_SPECULAR
    smoothness2 = clamp(smoothness, 0.0, 0.95);
    metalness = 1.0;
    #endif
}