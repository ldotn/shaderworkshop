Shader "Unlit/CelShaded"
{
    Properties
    {
        _DiffuseColor ("DiffuseColor", Color) = (1,1,1,1)
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _SpecularPower ("Specular Power", Range(0, 64)) = 8
        _SpecularIntensity ("Specular Intensity", Range(0, 2)) = 0.1
        _DiffuseShadingSteps ("Diffuse Shading Steps", Range(1, 10)) = 3
        _SpecularShadingSteps ("Specular Shading Steps", Range(1, 10)) = 2
    }
    SubShader
    {
        Tags 
        {
            "RenderType"="Opaque"
            "LightMode"="ForwardBase"
        }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "Shared.cginc"

            // compile shader into multiple variants, with and without shadows
            // (we don't care about any lightmaps yet, so skip these variants)
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            // shadow helper functions and macros
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            // The data that will be passed from the vertex shader to the pixel (fragment) shader
            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                SHADOW_COORDS(2)
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                float3 wpos : TEXCOORD3;
            };

            float4 _DiffuseColor;
            float4 _SpecularColor;
            float _DiffuseShadingSteps;
            float _SpecularShadingSteps;
            float _SpecularPower;
            float _SpecularIntensity;

            v2f vert (appdata v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.pos);
                o.uv = v.uv;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.wpos = mul(unity_ObjectToWorld, v.pos).xyz;

                UNITY_TRANSFER_FOG(o,o.pos);
                TRANSFER_SHADOW(o);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                // Fill inputs for the lighting function
                CelShadeInputs inputs;

                //    Fill constant values
                inputs.DiffuseColor = _DiffuseColor;
                inputs.SpecularColor = _SpecularColor;
                inputs.SpecularPower = _SpecularPower;
                inputs.SpecularIntensity = _SpecularIntensity;
                inputs.DiffuseShadingSteps = _DiffuseShadingSteps;
                inputs.SpecularShadingSteps = _SpecularShadingSteps;

                inputs.LightColor = _LightColor0.rgb;

                //    Compute light dependent values
                float3 worldNormal = normalize(i.normal);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);

                inputs.NdotL = saturate(dot(worldNormal, worldLightDir));

                float3 viewVector = normalize(_WorldSpaceCameraPos - i.wpos);
                float3 halfVector = normalize(viewVector + worldLightDir);
                
                inputs.NdotH = saturate(dot(worldNormal, halfVector));

                //    Sample shadows
                inputs.Attenuation = SHADOW_ATTENUATION(i);

                // Evaluate cel shaded model
                float3 lighting = ComputeCelShadedLighting(inputs);

                // Apply fog and output
                float4 colorOut = float4(lighting, 1);

                UNITY_APPLY_FOG(i.fogCoord, colorOut);

                return colorOut;
            }
            ENDCG
        }

        // pull in shadow caster from VertexLit built-in shader
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
