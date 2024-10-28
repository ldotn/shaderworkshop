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

            UNITY_DECLARE_TEX2D(_MainTex);
            UNITY_DECLARE_TEX2D(_CameraDepthTexture);
            UNITY_DECLARE_TEX2D(_CameraDepthNormalsTexture);
            float4x4 _ViewToWorld;

            float4 _SamplingKernel[16];

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
                        
            float3x3 BuildTangentFrame(float3 normal)
            {
                float3 dp1 = cross(normal, float3(0.0, 0.0, 1.0));
				float3 dp2 = cross(normal, float3(0.0, 1.0, 0.0));
				float3 t = length(dp1) > length(dp2) ? dp1 : dp2;
				t = normalize(t);
				float3 b = cross(normal, t);
				return float3x3(t, b, normal);
			}

            float CalculateAO(float2 uv, int N, float R, float3 vpos, float normal)
            {
                float ao = 0;
                int count = 0;
                
                float refDepth = 0;//LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
                float dx = ddx(refDepth);
                float dy = ddy(refDepth);
                float g = sqrt(dx * dx + dy * dy);

                float3x3 tangentFrame = BuildTangentFrame(normal);

                for (int i = 0; i < N; i++)
                {
                    /*float3 samplePos = wpos + mul(tangentFrame, _SamplingKernel[i].xyz);
                    float4 sampleUV = ComputeScreenPos(mul(UNITY_MATRIX_VP, float4(samplePos, 1)));
                    sampleUV /= sampleUV.w;*/

                    //float2 randomOffset = GenerateRandomOffset(uv, i, R);
                    //float2 sampleUV = uv + randomOffset;
                    float3 samplePos = vpos + mul(tangentFrame, _SamplingKernel[i].xyz);
                    float2 sampleUV = samplePos.xy;

                    if (IsValidSample(sampleUV))
                    {
                        float d = 0;//(refDepth - LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampleUV)));
                        float bias = 0.15;
                        ao += abs(d) < 0.005/g ? d : 0;//d < bias ? max(0,d / bias) : 0;//d * exp(-sharpness*d + bias);//exp(-sharpness*(d - bias)*(d-bias));
                        count++;
                    }
                }

                return ao / count;
            }
            /*
            // Function for converting depth to view-space position
            // in deferred pixel shader pass.  vTexCoord is a texture
            // coordinate for a full-screen quad, such that x=0 is the
            // left of the screen, and y=0 is the top of the screen.
            float3 VSPositionFromDepth(float2 vTexCoord)
            {
                // Get the depth value for this pixel
                float z = tex2D(_CameraDepthTexture, vTexCoord);  
                // Get x/w and y/w from the viewport position
                float x = vTexCoord.x * 2 - 1;
                float y = (1 - vTexCoord.y) * 2 - 1;
                float4 vProjectedPos = float4(x, y, z, 1.0f);
                // Transform by the inverse projection matrix
                float4 vPositionVS = mul(vProjectedPos, g_matInvProjection);  
                // Divide by w to get the view-space position
                return vPositionVS.xyz / vPositionVS.w;  
            }*/

            fixed4 frag (v2f i, float4 fragCoord : Sv_Position) : SV_Target
            {
                // Decode depth and normals from the camera Texture
                float depth;
                float3 normal;
                //DecodeDepthNormal(tex2D(_CameraDepthNormalsTexture, i.uv), depth, normal);

                // Convert normal to world space
                float3 wnormal = mul(_ViewToWorld, float4(normal, 0)).xyz;

                // Compute wpos from view vector and depth
                //float3 wpos = VSPositionFromDepth(i.uv.xy)
               // wpos = mul(_ViewToWorld, float4(normal, 0)).xyz;

               /* fixed4 col = tex2D(_MainTex, i.uv);
                // just invert the colors
                col.rgb = 1 - col.rgb;*/

                // Sample depth values from N random neighboring pixels selected uniformly in a radius R
                float N = 16;
                float R = 0.08;
                float ao = CalculateAO(i.uv, N, R, float3(i.uv, depth), normal);
                
                float z = max(1e-4, _CameraDepthTexture.Sample(sampler_CameraDepthTexture, i.uv).x);//LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));



                // Sample 3x3 grid of depth values
                float depthSamples[3][3];
                [unroll]
                for (int rx = -1; rx <= 1; rx++)
				{
					[unroll]
					for (int ry = -1; ry <= 1; ry++)
					{
						depthSamples[rx+1][ry+1] = _CameraDepthTexture.Sample(sampler_CameraDepthTexture, i.uv, int2(rx,ry)).x / z;//LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv + offset));
					}
				}
                // normalize by pixel depth
                
               // Convolve sobel kernel in X and Y
               float sobelX = -  depthSamples[0][0] +   depthSamples[0][2] 
                              -2*depthSamples[1][0] + 2*depthSamples[1][2] 
                              -  depthSamples[2][0] +   depthSamples[2][2];

               float sobelY = -  depthSamples[0][0] +   depthSamples[2][0] 
                              -2*depthSamples[0][1] + 2*depthSamples[2][1] 
                              -  depthSamples[0][2] +   depthSamples[2][2];

                float sobel = saturate(2*(sobelX*sobelX + sobelY*sobelY));
                float edge = pow(1 - sobel, 4);


                float4 color = _MainTex.Sample(sampler_MainTex, i.uv);

               return edge * color;
            }

            ENDHLSL
        }
    }
}
