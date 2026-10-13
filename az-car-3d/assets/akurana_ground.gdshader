shader_type spatial;
// Original inferred slope material, not mapped land cover.
varying vec3 world_pos;
varying vec3 world_normal;
uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_texture : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap;
uniform bool detail_normals = false;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
    float broad = noise(world_pos.xz * .017);
    float detail = noise(world_pos.xz * 2.7);
    float slope = 1.0 - abs(world_normal.y);
    vec3 grass = texture(grass_texture,world_pos.xz*.18).rgb * mix(vec3(.65,.72,.62),vec3(.9,.91,.75),broad);
    vec3 soil = texture(soil_texture,world_pos.xz*.17).rgb;
    ALBEDO = mix(grass,soil,smoothstep(.055,.28,slope)) * (.92+.12*detail);
    if (detail_normals) { NORMAL_MAP = texture(ground_normal,world_pos.xz*.17).rgb; NORMAL_MAP_DEPTH = .2; }
    ROUGHNESS = .97;
}
