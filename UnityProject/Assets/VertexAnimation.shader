Shader "Custom/WavyVertexShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Amplitude ("Amplitude", Float) = 0.1
        _Frequency ("Frequency", Float) = 1.0
        _Speed ("Speed", Float) = 1.0
        
        _DiffuseColor ("Color", Color) = (1,1,1,1)
        _SpecularColor ("Color", Color) = (1,1,1,1)
        _SpecularPower ("Specular Power", Range(0, 64)) = 8
        _SpecularIntensity ("Specular Intensity", Range(0, 2)) = 0.1
        _DiffuseShadingSteps ("Diffuse Shading Steps", Range(1, 10)) = 3
        _SpecularShadingSteps ("Specular Shading Steps", Range(1, 10)) = 2
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "Shared.cginc"
            #include "Lighting.cginc"

            // compile shader into multiple variants, with and without shadows
            // (we don't care about any lightmaps yet, so skip these variants)
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            // shadow helper functions and macros
            #include "AutoLight.cginc"
            #include "Shared.cginc"

            struct appdata
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 wpos : TEXCOORD2;
                UNITY_SHADOW_COORDS(3)
                UNITY_FOG_COORDS(4)
            };

            sampler2D _MainTex;
            float _Amplitude;
            float _Frequency;
            float _Speed;

            float4 _DiffuseColor;
            float4 _SpecularColor;
            float _SpecularPower;
            float _SpecularIntensity;
            float _DiffuseShadingSteps;
            float _SpecularShadingSteps;

            v2f vert (appdata v)
            {
                v2f o;
                v.pos.xyz += CalculateWindVertexDisp(v.pos, _Amplitude, _Frequency, _Time, _Speed);
                o.wpos = mul(unity_ObjectToWorld, v.pos);
                
                o.uv = v.uv;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.pos = UnityObjectToClipPos(v.pos);

                UNITY_TRANSFER_FOG(o,o.pos);
                UNITY_TRANSFER_SHADOW(o, o.pos);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Fill inputs for the lighting function
                CelShadeInputs inputs;

                //    Fill constant values
                inputs.DiffuseColor = _DiffuseColor;//lerp(float3(0.1,0.2,0.1), float3(0.5,0.8,0.5), i.wpos.y);
                inputs.SpecularColor = _SpecularColor;
                inputs.SpecularPower = _SpecularPower;
                inputs.SpecularIntensity = _SpecularIntensity;
                inputs.DiffuseShadingSteps = _DiffuseShadingSteps;
                inputs.SpecularShadingSteps = _SpecularShadingSteps;
                inputs.RimLightSharpness = 5;
                inputs.RimLightIntensity = 0.1;
                inputs.RimLightColor = 1;

                inputs.LightColor = _LightColor0.rgb;

                //    Compute light dependent values
                float3 worldNormal = normalize(i.normal);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);

                inputs.NdotL = saturate(dot(worldNormal, worldLightDir));

                float3 viewVector = normalize(_WorldSpaceCameraPos - i.wpos);
                float3 halfVector = normalize(viewVector + worldLightDir);
                
                inputs.NdotH = saturate(dot(worldNormal, halfVector));
                inputs.NdotV = saturate(dot(worldNormal, viewVector));

                //    Sample shadows
                inputs.Attenuation = UNITY_SHADOW_ATTENUATION(i, i.wpos);

                // Evaluate cel shaded model
                float3 lighting = ComputeCelShadedLighting(inputs);

                // Apply fog and output
                float4 colorOut = float4(lighting, 1);

                UNITY_APPLY_FOG(i.fogCoord, colorOut);

                return colorOut;
            }
            ENDCG
        }

        // shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc
        Pass
        {
            Tags {"LightMode"="ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"
            #include "Shared.cginc"

            struct v2f { 
                V2F_SHADOW_CASTER;
            };

            float _Amplitude;
            float _Frequency;
            float _Speed;

            v2f vert(appdata_base v)
            {
                v2f o;
                v.vertex.xyz += CalculateWindVertexDisp(v.vertex, _Amplitude, _Frequency, _Time, _Speed);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
