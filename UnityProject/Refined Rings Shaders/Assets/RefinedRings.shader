Shader "Hidden/RefinedRings"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _RingMap ("RingMap", 2D) = "white" {}
        _InnerRadius ("innerRadius", float) = 10
        _OuterRadius ("outerRadius", float) = 50
        _StepSize ("stepSize", float) = 0.1
        _MaxSteps ("maxSteps", int) = 700
        _Density ("density",float) = 1
        _Thickness ("thickness", float) = 1
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

            float3 _localX;
            float3 _localY;
            float3 _CornerVertexDist;
            float3 _WidthVertexDist;
            float3 _SunPos;
            float3 _SunColor;
            float _ClipPlaneHeight;
            const float PI = 3.14159265359;
            sampler2D _MainTex;
            sampler2D _RingMap;

            float _InnerRadius;
            float _OuterRadius;
            float _Thickness;
            float _StepSize;
            float3 _Center;
            float4 _ShadowCasters[1];
            float _Density;
            int _MaxSteps;

            float _farClipPlane;
            float _nearClipPlane;
            sampler2D _CameraDepthTexture;

            //float4(red,green,blue,density)
            float4 sampleDensityAtPoint(float3 pos)
            {
                float tiling = 200;

                float innerRadius = _InnerRadius;
                float outerRadius = _OuterRadius;
                float thickness = _Thickness;
                float3 centerPoint = _Center;


                float distanceToCenter = length(pos.xz - centerPoint.xz);
                float height = abs(pos.y - centerPoint.y);

                float2 uv = clamp(float2((distanceToCenter - innerRadius)/(outerRadius - innerRadius),height/thickness),0,0.95);

                float mult = 0;

                if (distanceToCenter > innerRadius && distanceToCenter < outerRadius && height < thickness) 
                    mult = 1;

                float4 amount = tex2D(_RingMap,uv);

                //amount = max((-pos.y*0.02)+0.2,0)*1;
                //amount = max((pos.y*0.02)-0.2,0)*1;
                //amount *= max(-abs(0.02*(pos.y-20))+0.1,0);
                //amount *= max(1+(sin(0.1*pos.x)),0);
                //amount *= 1;
                //amount *= mult;
                amount.a *= mult;
                amount.a *= _Density;
                amount.rgb *= _SunColor;
                //amount += clamp((-pos.y*0.02)+0.2,0,1)*1;
                //amount *= min(0.5 + tex2D(_Cloudmap, (pos.xz % tiling)/tiling).r,1);
                //amount = max((-pos.y*0.02)+0.2+0.25*sin(0.1*pos.x),0)*1;
                //amount = -pos.y;
                return amount;
            }
            

            float sdCappedCylinder( float3 p, float h, float r )
            {
              float2 d = abs(float2(length(p.xz),p.y)) - float2(h,r);
              return min(max(d.x,d.y),0.0) + length(max(d,0.0));
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

            bool HitSphere(float3 rayDir, float3 origin)
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

            /*
            DistanceRaymarcherResult GetDistance(float3 rayDir, float3 origin)
            {
                DistanceRaymarcherResult result;
                result.pos = origin;
                result.dist = 0;
                uint maxSteps = _MaxSteps;
                uint steps = 0;
                float dist = 9999999;
                bool hasCollided = false;

                while (steps < maxSteps && !hasCollided)
                {
                    dist = max(-1 * sdCappedCylinder(result.pos + float3(0,0,0), _InnerRadius, _Thickness * 2 + 1), sdCappedCylinder(result.pos + float3(0,0,0), _OuterRadius, _Thickness * 2));
                    result.pos += rayDir * dist;
                    result.dist += dist;
                    steps++;

                    if (dist < 0.5 * _Thickness/10)
                    {
                        hasCollided = true;
                    }
                }
                
                return result;
            }
            */

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

                /*
                bool ignoreScene = true;
                if (ignoreScene)
                    sceneDepth = 99999999;
                */

                while (stepsTaken < maxSteps && depth < sceneDepth)
                {
                    float4 sampledColor = sampleDensityAtPoint(rayPos);
                    float shadow = 1;
                    
                    
                    if (HitSphere(sun,rayPos))
                        shadow = 0;
                      

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

            float3 screenBlendMode(float3 a, float3 b)
            {
                return float3(1,1,1) - (float3(1,1,1) - a) * (float3(1,1,1) - b);
            }

            float3 addBlendMode(float3 a, float3 b)
            {
                return a + b;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float depth = Linear01Depth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, i.uv))); //Depth of the pixel in the camera frustum between 0 (near) and 1 (far)
                float depthWorldSpace = lerp(_nearClipPlane,_farClipPlane,depth); //Depth of the pixel in world units
                float3 rayDir = lerp(_CornerVertexDist,_WidthVertexDist,i.uv.x) + _localY * _ClipPlaneHeight * i.uv.y;
                float3 vertPos = _WorldSpaceCameraPos + rayDir;

                DistanceRaymarcherResult result = GetDistanceFromRing(rayDir,_WorldSpaceCameraPos);
                RayMarchResult raymarch = RayMarch(rayDir,result.pos,depthWorldSpace);

                
                //fixed4 col = fixed4(raymarch.col.r * raymarch.col.a,(1/result.dist * 10),(1/depthWorldSpace * 10),0);
                //fixed4 col = fixed4(GetDistanceFromRing(rayDir,_WorldSpaceCameraPos).dist/20,raymarch.col.g * raymarch.col.a,0,0);
                //fixed4 col = fixed4(raymarch.col.rgb * raymarch.col.a,0);
                
                /*
                if (result.dist > depthWorldSpace)
                {
                    col.r = 0;
                }

                //col.rgb = (GetDistanceFromRing(rayDir,_WorldSpaceCameraPos).dist/20) * float3(1,0,0);
                */

                //col.rgb = screenBlendMode(col.rgb,tex2D(_MainTex, i.uv).rgb);
                fixed4 col = float4(raymarch.col.rgb * raymarch.col.a + tex2D(_MainTex, i.uv).rgb * (1 - raymarch.col.a),1);
                //col.rgb += float3(0,0,0) * (1/result.dist * 10);

                /*
                float4 col = float4(1,1,1,1);
                
                if (HitSphere(rayDir,_WorldSpaceCameraPos))
                {
                    col.rgb = float3(1,0,0);
                }
                else
                {
                    col.rgb = float3(0,0,0);
                }
                */
                

                // just invert the colors
                
                return col;
            }
            ENDCG
        }
    }
}
