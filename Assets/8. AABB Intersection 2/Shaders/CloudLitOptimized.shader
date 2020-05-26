Shader "CloudLitOptimized"
{

Properties
{
    [Header(Base)]
    [Space(10)]
    _Color("Color", Color) = (1, 1, 1, 1)
    _Absorption("Absorption", Range(0, 100)) = 50
    _Opacity("Opacity", Range(0, 100)) = 50
    [PowerSlider(10.0)] _Step("Step", Range(0.001, 0.1)) = 0.03

    [Header(Noise)]
    [Space(10)]
    _NoiseScale("NoiseScale", Range(0, 100)) = 5
    _Radius("Radius", Range(0, 2)) = 1.0 

    [Header(Light)]
    [Space(10)]
    _AbsorptionLight("AbsorptionLight", Range(0, 100)) = 50
    _OpacityLight("OpacityLight", Range(0, 100)) = 50
    _LightStepScale("LightStepScale", Range(0, 1)) = 0.5
    [IntRange] _LoopLight("LoopLight", Range(0, 128)) = 6

    [Header(Optimize)]
    [Toggle] _DEBUG_RENDER_LOOP("DebugRenderLoop", Float) = 0
}

CGINCLUDE

#include "UnityCG.cginc"

struct appdata
{
    float4 vertex : POSITION;
};

struct v2f
{
    float4 vertex   : SV_POSITION;
    float3 worldPos : TEXCOORD1;
};

float4 _Color;
float _Step;
float _NoiseScale;
float _Radius;
float _Absorption;
float _Opacity;
float _AbsorptionLight;
float _OpacityLight;
int _LoopLight;
float _LightStepScale;
float4 _LightColor0;

// ref. https://www.shadertoy.com/view/lss3zr
inline float hash(float n)
{
    return frac(sin(n) * 43758.5453);
}

inline float noise(float3 x)
{
    float3 p = floor(x);
    float3 f = frac(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = p.x + p.y * 57.0 + 113.0 * p.z;
    float res = 
        lerp(lerp(lerp(hash(n +   0.0), hash(n +   1.0), f.x),
                  lerp(hash(n +  57.0), hash(n +  58.0), f.x), f.y),
             lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
                  lerp(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
    return res;
}

inline float fbm(float3 p)
{
    float3x3 m = float3x3(
        +0.00, +0.80, +0.60,
        -0.80, +0.36, -0.48,
        -0.60, -0.48, +0.64);
    float f = 0.0;
    f += 0.5 * noise(p); p = mul(m, p) * 2.02;
    f += 0.3 * noise(p); p = mul(m, p) * 2.03;
    f += 0.2 * noise(p);
    return f;
}

inline float densityFunction(float3 p)
{	
	return fbm(p * _NoiseScale) - length(p / _Radius);
}

v2f vert(appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    return o;
}

float4 frag(v2f i) : SV_Target
{
    float3 worldPos = i.worldPos;
    float3 worldDir = normalize(worldPos - _WorldSpaceCameraPos);

    float3 localPos = mul(unity_WorldToObject, float4(worldPos, 1.0));
    float3 localDir = UnityWorldToObjectDir(worldDir);
    float3 localStep = localDir * _Step;
    float jitter = hash(localPos.x + localPos.y * 10 + localPos.z * 100 + _Time.x);
    localPos += jitter * localStep;

    float3 invLocalDir = 1.0 / localDir;
    float3 t1 = (-0.5 - localPos) * invLocalDir;
    float3 t2 = (+0.5 - localPos) * invLocalDir;
    float3 tmax3 = max(t1, t2);
    float2 tmax2 = min(tmax3.xx, tmax3.yz);
    float traverseDist = min(tmax2.x, tmax2.y);
    int loop = floor(traverseDist / _Step);

    float lightStep = 1.0 / _LoopLight;
    float3 localLightDir = UnityWorldToObjectDir(_WorldSpaceLightPos0.xyz);
    float3 localLightStep = localLightDir * lightStep * _LightStepScale;

    float4 color = float4(_Color.rgb, 0.0);
    float transmittance = 1.0;

#ifdef _DEBUG_RENDER_LOOP_ON
    int n = 0;
#endif

    for (int i = 0; i < loop; ++i)
    {
        float density = densityFunction(localPos);

        if (density > 0.0)
        {
            float d = density * _Step;
            transmittance *= 1.0 - d * _Absorption;
            if (transmittance < 0.01) break;

            float transmittanceLight = 1.0;
            float3 lightPos = localPos;

            for (int j = 0; j < _LoopLight; ++j)
            {
                float densityLight = densityFunction(lightPos);

                if (densityLight > 0.0)
                {
                    float dl = densityLight * lightStep;
                    transmittanceLight *= 1.0 - dl * _AbsorptionLight;
                    if (transmittanceLight < 0.01) 
                    {
                        transmittanceLight = 0.0;
                        break;
                    }
                }

                lightPos += localLightStep;
            }

            color.a += _Color.a * (_Opacity * d * transmittance);
            color.rgb += _LightColor0 * (_OpacityLight * d * transmittance * transmittanceLight);
        }

        color = clamp(color, 0.0, 1.0);

        localPos += localStep;

#ifdef _DEBUG_RENDER_LOOP_ON
        ++n;
#endif
    }

#ifdef _DEBUG_RENDER_LOOP_ON
    return float4(n * _Step, 0.0, 0.0, 1.0);
#else
    return color;
#endif
}

ENDCG

SubShader
{

Tags 
{ 
    "Queue" = "Transparent"
    "RenderType" = "Transparent" 
}

Pass
{
    Cull Back
    ZWrite Off
    Blend SrcAlpha OneMinusSrcAlpha
    Lighting Off

    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag
    #pragma shader_feature _DEBUG_RENDER_LOOP_ON
    ENDCG
}

}

}