Shader "Unlit/CelShaded"
{
    Properties
    {
        _DiffuseColor ("Color", Color) = (1,1,1,1)
        _SpecularColor ("Color", Color) = (1,1,1,1)
        _SpecularPower ("Specular Power", Range(0, 64)) = 8
        _SpecularIntensity ("Specular Intensity", Range(0, 2)) = 0.1
        _ShadingSteps ("Shading Steps", Range(1, 10)) = 3
    }
    SubShader
    {
        Tags {"LightMode"="ForwardBase"}
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

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                SHADOW_COORDS(2) // put shadows data into TEXCOORD1
                float4 pos : SV_POSITION;
                float3 normal : NORMAL;
                float3 wpos : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _DiffuseColor;
            float4 _SpecularColor;
            float _ShadingSteps;
            float _SpecularPower;
            float _SpecularIntensity;
            float4 _AmbientColor;

            v2f vert (appdata v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.pos);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.wpos = mul(unity_ObjectToWorld, v.pos).xyz;

                UNITY_TRANSFER_FOG(o,o.pos);
                TRANSFER_SHADOW(o);

                return o;
            }

            float QuantizeIntensity(float intensity, float transitionRadius, float steps)
            {
                float r = 0.5 - transitionRadius; // TODO : remove

                intensity *= steps;
                float transition = frac(intensity);
                transition = saturate((transition - r) / (1 - 2*r));
                transition = smoothstep(0, 1, transition);

                intensity = floor(intensity) + transition;
                intensity /= steps;

                return intensity;
			}

            float4 frag (v2f i) : SV_Target
            {
                float3 lightColor = _LightColor0.rgb;

                // apply lighting
                float3 worldNormal = normalize(i.normal);
                float3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                
                float diffuse = max(dot(worldNormal, worldLightDir), 0.0);

                float3 viewVector = normalize(_WorldSpaceCameraPos - i.wpos);
                float3 halfVector = normalize(viewVector + worldLightDir);
                float specular = pow(max(dot(worldNormal, halfVector), 0.0), _SpecularPower);

                // apply shadows
                float shadow = SHADOW_ATTENUATION(i);
                diffuse *= shadow;
                specular *= shadow;

                // quantize color
                diffuse = QuantizeIntensity(diffuse, 0.05, _ShadingSteps);
                specular = QuantizeIntensity(specular, 0.05, 2);

                // Apply fog and output
                float4 colorOut = float4(lightColor * (_DiffuseColor*diffuse + _SpecularColor*_SpecularIntensity*specular), 1);

                UNITY_APPLY_FOG(i.fogCoord, colorOut);

                return colorOut;
            }
            ENDCG
        }

        // pull in shadow caster from VertexLit built-in shader
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
