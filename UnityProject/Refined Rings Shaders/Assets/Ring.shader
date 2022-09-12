Shader "Hidden/Ring"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RingMap ("RingMap", 2D) = "white" {}
        _InnerRadius ("_InnerRadius", float) = 10
        _OuterRadius ("_OuterRadius", float) = 50
        _StepSize ("stepSize", float) = 0.1
        _MaxSteps ("maxSteps", int) = 700
        _Density ("density",float) = 1
        _Thickness ("_Thickness", float) = 1
        _Center ("center", Vector) = (0,0,0,0)
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

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
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            struct DistanceRaymarcherResult
            {
                float3 pos;
                float dist;
            };

            struct RayMarchResult
            {
                float4 col;
                float depth;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            sampler2D _RingMap;
            float _InnerRadius;
            float _OuterRadius;
            float _Thickness;
            float _StepSize;
            float3 _Center;
            float3 _SunPos;
            float4 _ShadowCasters[1];
            float _Density;
            int _MaxSteps;

            float4 sampleDensityAtPoint(float3 pos)
            {
                float distanceToCenter = length(pos.xz - _Center.xz); //distance in ring from inner to outer
                float height = abs(pos.y - _Center.y); //height inside the ring

                float2 uv = clamp(float2((distanceToCenter - _InnerRadius)/(_OuterRadius - _InnerRadius),height/_Thickness),0,0.95);

                float mult = 0;

                if (distanceToCenter > _InnerRadius && distanceToCenter < _OuterRadius && height < _Thickness) 
                    mult = 1;

                float4 amount = tex2D(_RingMap,uv);

                amount.a *= mult;
                amount.a *= _Density;
                //amount.rgb *= _SunColor;

                return amount;
            }

            float sdCappedCylinder( float3 p, float h, float r )
            {
              float2 d = abs(float2(length(p.xz),p.y)) - float2(h,r);
              return min(max(d.x,d.y),0.0) + length(max(d,0.0));
            }

            bool HitSphere(float3 rayDir, float3 origin) //for calculating shadow
            {
                bool result = false;
                float3 rayPos = origin;
                uint stepsTaken = 0;
                uint maxSteps = 20;

                while (!result && stepsTaken < maxSteps)
                {
                    float dist = 99999999;
                    for (int i = 0; i < 1; i++)
                    {
                        dist = min(abs(length(rayPos - _ShadowCasters[i].xyz)) - _ShadowCasters[i].w,dist);
                    }

                    if (dist < 0.5)
                    {
                        result = true;
                    }
                    else
                    {
                        rayPos += rayDir * dist;
                        stepsTaken++;
                    }
                }

                return result;
            }

            DistanceRaymarcherResult GetDistanceFromRing(float3 rayDir, float3 origin)
            {
                DistanceRaymarcherResult result;
                result.pos = origin;
                result.dist = 0;
                rayDir = normalize(rayDir);
                int stepsTaken = 0;
                float depth = 0;
                bool hasCollided = false;
                //result.col = float4(Skybox_Atmosphere(rayDir, float4(1, 0.501, 0.278,2.3)),1);
                
                while (!hasCollided && stepsTaken < 50)
                {
                    //float dist = sdTorus(rayPos, float2((_OuterRadius-_InnerRadius)/2+_InnerRadius,(_OuterRadius-_InnerRadius)/2));
                    
                    //float dist = sdBox(rayPos, float3(1,1,1));
                    //float dist = sdCappedCylinder(rayPos,1,1);
                    float dist = max(-1 * sdCappedCylinder(result.pos + float3(0,0,0), _InnerRadius, _Thickness * 2 + 1), sdCappedCylinder(result.pos + float3(0,0,0), _OuterRadius, _Thickness * 2));


                    if (dist < 0.4)
                    {
                        //result.col = float4(0.5*sin(rayPos)+0.5,1);
                        //result = abs(length(rayPos - _WorldSpaceCameraPos));
                        result.dist = depth;
                        hasCollided = true;
                    }
                    else
                    {
                        result.pos += rayDir * dist;
                        depth += dist;
                        stepsTaken++;
                    }
                }

                return result;
            }

            RayMarchResult RayMarch(float3 rayDir, float3 origin, float sceneDepth)
            {
                RayMarchResult result;
                float3 rayPos = origin;
                rayDir = normalize(rayDir);
                result.col = float4(0,0,0,0);
                result.depth = 0;
                float depth = length(origin - _WorldSpaceCameraPos);
                uint stepsTaken = 0;
                int maxSteps = 400;
                float stepSize = _StepSize;
                float3 averageColor = float3(0,0,0);
                float colorweight = 0;
                float accumulation = 0;
                float3 sun = -normalize(_SunPos);

                while (stepsTaken < maxSteps && depth < sceneDepth)
                {
                    float4 sampledColor = sampleDensityAtPoint(rayPos);
                    float shadow = 1;
                    
                    
                    //if (HitSphere(sun,rayPos))
                    //    shadow = 0;
                      

                    averageColor += (sampledColor.rgb * shadow) * sampledColor.a;
                    colorweight += sampledColor.a;

                    accumulation += stepSize * sampledColor.a;

                    

                    rayPos += rayDir * stepSize;
                    depth += stepSize;

                    if (stepsTaken % uint(100) == uint(99))
                    {
                        stepSize *= 2;
                    }
                    
                    //brightness -= (1/exp(LightMarch(10,1,normalize(_SunPos),rayPos,999999,true))) * (1 - accumulation/finalAccumulation) * sampleDensityAtPoint(rayPos);
                    stepsTaken++;
                }

                averageColor /= colorweight + 0.00000001;

                float light = (dot(-sun,rayDir)+1)*0.5; //angle between the viewray and the sun


                float backGlow = 1; //intensity of the glow around the sun
                float glowExponent = 10; //inverse size (area) of the backglow
                float lightMult = 1; //intensity of the normal sunlit part
                float darkTransparency = 0; //wether the dark parts should be opaque or transparent 
                float selfShadow = 0.25; //0 no shadow

                float lit = clamp(((light*lightMult) + (backGlow*pow(1 - light,glowExponent))) * lerp(1,1/exp(0.25*accumulation),(1 - pow(light,0.5)) * selfShadow),0,1);
                averageColor *= lerp(lit,1,darkTransparency);

                //result.col = float4(averageColor,1);
                //result.col = float4(clamp(1-1/exp(1*accumulation),0,1),1);
                //float3(1,1,1)
                result.col = float4(averageColor,lerp(1,lit,darkTransparency) * clamp(1-1/exp(1*accumulation),0,1));


                return result;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                // just invert the colors
                col.rgb = 1 - col.rgb;
                return col;
            }
            ENDCG
        }
    }
}
