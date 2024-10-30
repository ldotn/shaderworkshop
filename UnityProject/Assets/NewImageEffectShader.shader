Shader "Hidden/NewImageEffectShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _SSAORadius ("SSAO Radius", Float) = 0.1
        _SSAOBias ("SSAO Bias", Float) = 1.0
        _SSAOCutoffRadius ("SSAO Cutoff Radius", Float) = 0.1
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
            float4x4 _ViewProj;
            float4x4 _InvProj;
            float4x4 _Proj;

            float _SSAORadius;
            float _SSAOBias;
            float _SSAOCutoffRadius;

            float4 _SamplingKernel[16];

            // This is a very ugly way to generate ""random"" numbers, but it's good enough for this example
            // A much better way is to use a precomputed texture with random values, normally blue noise
            // Or a low discrepancy sequence like Halton or Hammersley
            float3 GetRandom3(float2 uv, float i)
            {
			    return float3(
					frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453 + i),
					frac(cos(dot(uv, float2(12.9898, 78.233))) * 43758.5453 + i),
                    frac(cos(dot(uv, float2(78.9898, 12.233))) * 34758.5453 + i)
				);
            }

            bool IsValidSample(float2 sampleUV)
            {
                return sampleUV.x >= 0 && sampleUV.x <= 1 && sampleUV.y >= 0 && sampleUV.y <= 1;
            }

            float CalculateAO(float2 uv, int N, float R, float3 wpos, float3 normal)
            {
                float ao = 0;
                
                float refDepth = LinearEyeDepth(_CameraDepthTexture.Sample(sampler_CameraDepthTexture, uv).x);

                // By choosing a random vector as one of our basis vectors, we can create a random tangent space
                // We are constructing the tangent space using Gram-Schmidt orthogonalization
                float3 randomVec = GetRandom3(uv, 0);
                float3 tangent   = normalize(randomVec - normal * dot(randomVec, normal));
                float3 bitangent = cross(normal, tangent);

                float3x3 tangentFrame = float3x3(tangent, bitangent, normal);  
                
                for (int i = 0; i < N; i++)
                {
                    float3 kernelDirection = _SamplingKernel[i].xyz;

                    float3 samplePos = wpos + _SSAORadius*mul(tangentFrame, kernelDirection);
                    float4 sampleClip = ComputeScreenPos(mul(_ViewProj, float4(samplePos, 1)));
                    sampleClip /= sampleClip.w;

                    sampleClip.z = LinearEyeDepth(sampleClip.z);

                    if (IsValidSample(sampleClip.xy))
                    {
                        float d = LinearEyeDepth(_CameraDepthTexture.Sample(sampler_CameraDepthTexture, sampleClip.xy).x);
                       
                        float bias = _SSAOBias;
                        float radius = _SSAOCutoffRadius;
                        float rangeCheck = smoothstep(0.0, 1.0, radius / abs(refDepth - d));
                        
                        // This is a variant of the standard SSAO occlusion estimation, in this case we are comparing the difference of normals
                        // If the nearby surfaces have very different normals, we can guess that the surface will be more occluded
                        // The depth is used to ignore samples that are too far away
                        // I'm doing this because it's a bit easier to get a consistent effect, but you shouldn't take it as something to go home with
                        // Nailing down the occlusion test in SSAO is always a tricky thing
                        float sz;
                        float3 sn;
                        DecodeDepthNormal(_CameraDepthNormalsTexture.Sample(sampler_CameraDepthNormalsTexture, sampleClip.xy), sz, sn);
                        sn = mul((float3x3)_ViewToWorld, sn);
                        ao += saturate(dot(normal, sn))*rangeCheck;
                    }
                    else
                    {
						ao += 1;
					}
                }

                return ao / N;
            }

            float3 ReconstructWorldPosition(float2 uv, float depth)
            {
                // Get the screen space position
                float4 screenPos = float4(uv * 2.0 - 1.0, depth, 1.0);

                // Transform by the inverse projection matrix
                float4 viewPos = mul(_InvProj, screenPos);

                // Divide by w to get the view-space position
                viewPos /= viewPos.w;

                // Transform by the inverse view matrix to get the world-space position
                float3 worldPos = mul(_ViewToWorld, viewPos).xyz;

                return worldPos;
            }

            fixed4 frag (v2f i, float4 fragCoord : Sv_Position) : SV_Target
            {
                // Decode depth and normals from the camera Texture
                float depthLinear;
                float3 normal;
                DecodeDepthNormal(_CameraDepthNormalsTexture.Sample(sampler_CameraDepthNormalsTexture, i.uv), depthLinear, normal);

                // Convert normal to world space
                // Using (float3x3) here is to only keep the rotation part of the matrix, as we don't want translation for normals
                float3 wnormal = mul((float3x3)_ViewToWorld, normal);

                // Compute wpos from view vector and depth
                float z = max(1e-4, _CameraDepthTexture.Sample(sampler_CameraDepthTexture, i.uv).x);
                float3 wpos = ReconstructWorldPosition(i.uv.xy, z);

                // Sample depth values from N random neighboring pixels selected uniformly in a radius R
                float N = 16;
                float R = 0.08;

                float ao = CalculateAO(i.uv, N, R, wpos, wnormal);


                // Sample 3x3 grid of depth values
                // For simplicity, I'm keeping this separate from the depth samples of the SSAO pass, but if possible you should reuse them
                float depthSamples[3][3];
                [unroll]
                for (int rx = -1; rx <= 1; rx++)
				{
					[unroll]
					for (int ry = -1; ry <= 1; ry++)
					{
                        // Normalizing by the pixel depth is optional, but gives us the same edge intensity regardless of distance
                        // Otherwise objects close to the camera will have weaker edges than far away objects
						depthSamples[rx+1][ry+1] = _CameraDepthTexture.Sample(sampler_CameraDepthTexture, i.uv, int2(rx,ry)).x / z;
					}
                }
                
                // Convolve sobel kernel in X and Y
                float sobelX = -  depthSamples[0][0] +   depthSamples[0][2] 
                              -2*depthSamples[1][0] + 2*depthSamples[1][2] 
                              -  depthSamples[2][0] +   depthSamples[2][2];

                float sobelY = -  depthSamples[0][0] +   depthSamples[2][0] 
                              -2*depthSamples[0][1] + 2*depthSamples[2][1] 
                              -  depthSamples[0][2] +   depthSamples[2][2];

                // Calculate edge intensity from the gradient squared magnitude
                // This is scaled and clamped to 0-1 (saturate), then inverted and raised to a power to control the sharpness
                float preSaturateIntensity = 2;
                float edgeSharpness = 4;
                float sobel = saturate(preSaturateIntensity*(sobelX*sobelX + sobelY*sobelY));
                float edge = pow(1 - sobel, edgeSharpness);
                
                // Square the AO to make it more pronounced
                ao *= ao;
                float3 viewVector = normalize(_WorldSpaceCameraPos - wpos);
                float4 color = _MainTex.Sample(sampler_MainTex, i.uv);

                float rimL = pow(1 - saturate(dot(wnormal, viewVector)), 5);

               return ao*(0.01 + 0.2*rimL) + edge*color;
            }

            ENDHLSL
        }
    }
}
