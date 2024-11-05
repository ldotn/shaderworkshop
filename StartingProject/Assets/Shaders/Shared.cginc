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
    return intensity;
}

float3 ComputeCelShadedLighting(CelShadeInputs inputs)
{
    return 0;
}

// Calculate wind displacement in local space following Blender's Z=up convention
// This should be in world space, otherwise the displacements aren't stable with scaling or rotations, but Unity's macros for shadowing expect inputs in local space, so for simplicity I keep it in local space
float3 CalculateWindVertexDispLocalXZY(float3 vertex, float amplitude, float frequency, float time, float speed)
{
    // Add a diagonal movement by tiling a sin wave based on the xy coordinates (the forward/backward | left/right plane)
    float gust = sin(frequency * vertex.x*vertex.y + time * speed) * amplitude;
    
    // Multiplying by the vertex z (height) makes it so that the root of the grass stay fixed while the tips wave more
    return float3(0, gust, 0) * vertex.z;
}

#endif