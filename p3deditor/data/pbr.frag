#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif

// Material uniforms
uniform vec3 albedo;
uniform float metallic;
uniform float roughness;

// v0.8.0: Textures
uniform sampler2D albedoMap;
uniform bool hasAlbedoMap;
uniform sampler2D metallicMap;
uniform bool hasMetallicMap;
uniform sampler2D roughnessMap;
uniform bool hasRoughnessMap;

// v0.8.0: IBL Environment
uniform sampler2D envMap;
uniform bool hasEnvMap;
uniform float envMapIntensity; // v2.3: Global intensity control

// v0.8.5: World-Space uniforms
uniform vec3 cameraPos; // World camera position

// Light uniforms (view space)
uniform vec3 lightPositions[5]; // View-space light positions
uniform vec3 lightColors[5];    // Light RGB intensities
uniform int lightCount;

varying vec3 vertNormal;
varying vec3 vertPos;
varying vec2 vertTexCoord;

// v0.8.5: World-Space varyings
varying vec3 worldPos;
varying vec3 worldNormal;

const float PI = 3.14159265359;

// Trowbridge-Reitz GGX Distribution
float DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    return nom / max(denom, 0.0000001);
}

// Schlick-GGX Geometry
float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    return nom / denom;
}

// Smith-Schlick Geometry
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);
    return ggx1 * ggx2;
}

// Fresnel Schlick
vec3 FresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// v0.8.5: Fresnel Schlick with Roughness (for IBL)
vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
    return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Equirectangular mapping function
vec2 SampleSphericalMap(vec3 v) {
    vec2 uv = vec2(atan(v.z, v.x), asin(v.y));
    uv *= vec2(0.1591, 0.3183); // 1/2PI, 1/PI
    uv += 0.5;
    return uv;
}

// Manual Blur sampling for IBL fallback - High-Strength 9-Tap Version
vec3 sampleIBL(sampler2D map, vec3 dir, float rough) {
    vec2 uv = SampleSphericalMap(dir);
    if (rough <= 0.05) return texture2D(map, uv).rgb;
    
    // 9-tap blur for a much stronger effect at high roughness
    float offset = rough * 0.08; // Increased up to 8% of the texture width
    vec3 c = texture2D(map, uv).rgb * 0.2; // Center
    
    // Orthogonal taps
    c += texture2D(map, uv + vec2(offset, 0.0)).rgb * 0.1;
    c += texture2D(map, uv + vec2(-offset, 0.0)).rgb * 0.1;
    c += texture2D(map, uv + vec2(0.0, offset)).rgb * 0.1;
    c += texture2D(map, uv + vec2(0.0, -offset)).rgb * 0.1;
    
    // Diagonal taps
    float diag = offset * 0.707;
    c += texture2D(map, uv + vec2(diag, diag)).rgb * 0.1;
    c += texture2D(map, uv + vec2(-diag, -diag)).rgb * 0.1;
    c += texture2D(map, uv + vec2(diag, -diag)).rgb * 0.1;
    c += texture2D(map, uv + vec2(-diag, diag)).rgb * 0.1;
    
    return c;
}

void main() {
    vec3 N = normalize(vertNormal);
    vec3 V = normalize(-vertPos); // Camera is at 0,0,0 in view space
    
    // v0.8.5: World-Space Normal & View direction
    vec3 worldN = normalize(worldNormal);
    vec3 worldV = normalize(cameraPos - worldPos);

    // v0.8.0: Texture Sampling
    // v0.8.5: Albedo Handling
    vec3 baseAlbedo = albedo;
    if (hasAlbedoMap) {
        baseAlbedo = texture2D(albedoMap, vertTexCoord).rgb;
    }
    
    float met = metallic;
    if (hasMetallicMap) met *= texture2D(metallicMap, vertTexCoord).r;
    
    float rough = roughness;
    if (hasRoughnessMap) rough *= texture2D(roughnessMap, vertTexCoord).r;
    rough = clamp(rough, 0.05, 1.0);

    // Surface reflection at zero incidence
    vec3 F0 = vec3(0.04);
    F0 = mix(F0, baseAlbedo, met);

    vec3 Lo = vec3(0.0);
    for (int i = 0; i < 5; ++i) {
        if (i >= lightCount) break;

        // Calculate per-light radiance
        vec3 L = normalize(lightPositions[i] - vertPos);
        vec3 H = normalize(V + L);
        float distance = length(lightPositions[i] - vertPos);
        
        float attenuation = 10000.0 / (distance * distance + 100.0); 
        vec3 radiance = lightColors[i] * attenuation;

        // Cook-Torrance BRDF
        float D = DistributionGGX(N, H, rough);
        float G = GeometrySmith(N, V, L, rough);
        vec3 F = FresnelSchlick(max(dot(H, V), 0.0), F0);

        vec3 numerator = D * G * F;
        float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
        vec3 specular = numerator / denominator;

        vec3 kS = F;
        vec3 kD = vec3(1.0) - kS;
        kD *= (1.0 - met);

        float NdotL = max(dot(N, L), 0.0);
        Lo += (kD * baseAlbedo / PI + specular) * radiance * NdotL;
    }

    // Default Ambient
    vec3 ambient = vec3(0.03) * baseAlbedo;
    
    // v0.8.5: Advanced World-Space IBL
    if (hasEnvMap) {
        // v0.8.5: Use WORLD-SPACE reflection vector
        vec3 worldR = reflect(-worldV, worldN); 
        float NdotV = max(dot(worldN, worldV), 0.0);
        
        // Specular IBL (Prefiltered color approximation)
        vec3 prefilteredColor = sampleIBL(envMap, worldR, rough);
        vec3 F = FresnelSchlickRoughness(NdotV, F0, rough);
        
        // Split-sum approximation: ensures reflections fade with roughness
        float envBRDF_scale = clamp(1.0 - rough, 0.0, 1.0);
        float envBRDF_bias = rough * 0.02; 
        vec3 specularIBL = prefilteredColor * (F * envBRDF_scale + envBRDF_bias);
        
        // v0.8.5: Irradiance IBL (Diffuse ambient from environment)
        vec3 irradiance = sampleIBL(envMap, worldN, 1.0);
        irradiance += sampleIBL(envMap, worldN + vec3(0.2, 0, 0), 1.0);
        irradiance += sampleIBL(envMap, worldN + vec3(-0.2, 0, 0), 1.0);
        irradiance += sampleIBL(envMap, worldN + vec3(0, 0.2, 0), 1.0);
        irradiance += sampleIBL(envMap, worldN + vec3(0, -0.2, 0), 1.0);
        irradiance /= 5.0;
        
        vec3 kS = F;
        vec3 kD = (vec3(1.0) - kS) * (1.0 - met);
        vec3 diffuseIBL = irradiance * baseAlbedo;
        
        // Master Balance: Combined IBL contribution scaled by global intensity
        ambient = (kD * diffuseIBL + specularIBL) * envMapIntensity;
    }

    vec3 color = ambient + Lo;

    // HDR tone mapping (Simple Reinhard)
    color = color / (color + vec3(1.0));
    // Gamma correction
    color = pow(color, vec3(1.0/2.2));

    gl_FragColor = vec4(color, 1.0);
}
