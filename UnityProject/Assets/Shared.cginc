#ifndef SHARED_CGINC
#define SHARED_CGINC

struct CelShadeInputs
{
    float3 DiffuseColor;
    float3 SpecularColor;
    
    float SpecularPower;
    float SpecularIntensity;
    
    float DiffuseShadingSteps;
    float SpecularShadingSteps;

    float3 LightColor;
    float NdotL; // Saturated
    float NdotH;
    float Attenuation;
};

float QuantizeIntensity(float intensity, float steps)
{
    float transitionRadius = 0.05;
    float r = 0.5 - transitionRadius;

    intensity *= steps;
    float transition = frac(intensity);
    transition = saturate((transition - r) / (1 - 2 * r));

    intensity = floor(intensity) + transition;
    intensity /= steps;

    return intensity;
}

float3 ComputeCelShadedLighting(CelShadeInputs inputs)
{
    // Calculate Blinn-Phong lighting and quantize the result
    // Note : We combine the attenuation here so it gets quantized as well
    float diffuse = inputs.NdotL * inputs.Attenuation;
    diffuse = QuantizeIntensity(diffuse, inputs.DiffuseShadingSteps);
    
    float specular = pow(inputs.NdotH, inputs.SpecularPower) * inputs.Attenuation;
    specular = QuantizeIntensity(specular, inputs.SpecularShadingSteps);

    // Combine diffuse and specular lighting
    return   diffuse * inputs.DiffuseColor 
           + specular * inputs.SpecularColor * inputs.SpecularIntensity;
}

float3 CalculateWindVertexDisp(float3 vertex, float amplitude, float frequency, float time, float speed)
{
    // Base Waving
    float waveX = sin(frequency * vertex.x + time * speed) * amplitude;
    float waveY = cos(frequency * vertex.y + time * speed) * amplitude;
    
    // Add a diagonal gusts at a much lower frequency
    float gust = 1*sin(1*frequency * vertex.x*vertex.y + time * speed) * amplitude;
    
    return float3(0, gust, 0) * vertex.z * 10;

}

#endif