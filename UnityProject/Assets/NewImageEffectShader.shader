Shader "Hidden/NewImageEffectShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;

            float2 GenerateRandomOffset(float2 uv, int sample, float R)
            {
                // Generate a random number from the uv coordinates
                float2 rng = frac(sin(dot(uv + sample, float2(12.9898, 78.233))) * 43758.5453);
                float angle = rng.x*2 * 3.14159;
                float distance = sqrt(rng.y) * R;
                return float2(cos(angle), sin(angle)) * distance;
            }

            bool IsValidSample(float2 sampleUV)
            {
                return sampleUV.x >= 0 && sampleUV.x <= 1 && sampleUV.y >= 0 && sampleUV.y <= 1;
            }

            float CalculateAO(float2 uv, int N, float R)
            {
                float ao = 0;
                int count = 0;
                
                float refDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
                float dx = ddx(refDepth);
                float dy = ddy(refDepth);
                float g = sqrt(dx * dx + dy * dy);
                for (int i = 0; i < N; i++)
                {
                    float2 randomOffset = GenerateRandomOffset(uv, i, R);
                    float2 sampleUV = uv + randomOffset;

                    if (IsValidSample(sampleUV))
                    {
                        float d = (refDepth - LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampleUV)));
                        float bias = 0.15;
                        ao += abs(d) < 0.005/g ? d : 0;//d < bias ? max(0,d / bias) : 0;//d * exp(-sharpness*d + bias);//exp(-sharpness*(d - bias)*(d-bias));
                        count++;
                    }
                }

                return ao / count;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                // just invert the colors
                col.rgb = 1 - col.rgb;

                // Sample depth values from N random neighboring pixels selected uniformly in a radius R
                float N = 16;
                float R = 0.08 / LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));
                float ao = CalculateAO(i.uv, N, R);
                
                float z = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));

                return pow(saturate(1 - ao), 10);
            }

            ENDHLSL
        }
    }
}
