Shader "Custom/WavyVertexShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Amplitude ("Amplitude", Float) = 0.1
        _Frequency ("Frequency", Float) = 1.0
        _Speed ("Speed", Float) = 1.0
        _RefractionDepth ("RefractionDepth", Float) = 0.5
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

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float3 wpos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float _Amplitude;
            float _Frequency;
            float _Speed;
            float _RefractionDepth;

            v2f vert (appdata v)
            {
                v2f o;
                float wave = sin(_Frequency * v.vertex.x + _Time * _Speed) * _Amplitude;
                v.vertex.y += wave;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Calculate refraction sample uv
                float3 refractionDir = refract(normalize(i.normal), normalize(i.wpos.xyz), 0.5);
                float3 refractionRayEnd = i.wpos + refractionDir * _RefractionDepth;
                
                float4 sampleUV = 0;//mul(_WorldToClip, float4(refractionRayEnd, 1));
                sampleUV.xy /= sampleUV.w;
                sampleUV.xy = sampleUV.xy * 0.5 + 0.5;
                
                fixed4 col = tex2D(_MainTex, sampleUV);
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
