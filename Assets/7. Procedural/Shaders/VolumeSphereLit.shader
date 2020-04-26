Shader "VolumeSphereLit"{

Properties
{
    [Header(Base)]
    [Space(10)]
    _Color("Color", Color) = (1, 1, 1, 1)
    _Absorption("Absorption", Range(0, 100)) = 50
    _Opacity("Opacity", Range(0, 100)) = 50
    [IntRange] _Loop("Loop", Range(0, 128)) = 32

    [Header(Light)]
    [Space(10)]
    _AbsorptionLight("AbsorptionLight", Range(0, 100)) = 50
    _OpacityLight("OpacityLight", Range(0, 100)) = 50
    [IntRange] _LoopLight("LoopLight", Range(0, 128)) = 6
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
float _Absorption;
float _Opacity;
int _Loop;
float _AbsorptionLight;
float _OpacityLight;
int _LoopLight;
float4 _LightColor0;

inline float densityFunction(float3 p)
{	
	return 0.5 - length(p);
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
    float step = 1.0 / _Loop;
    float3 worldPos = i.worldPos;
    float3 worldDir = normalize(worldPos - _WorldSpaceCameraPos);

    float3 localPos = mul(unity_WorldToObject, float4(worldPos, 1.0)).xyz;
    float3 localDir = UnityWorldToObjectDir(worldDir);
    float3 localStep = localDir * step;

    float lightStep = 1.0 / _LoopLight;
    float3 localLightDir = UnityWorldToObjectDir(_WorldSpaceLightPos0.xyz);
    float3 localLightStep = localLightDir * lightStep * 0.5;

    float4 color = float4(_Color.rgb, 0.0);
    float transmittance = 1.0;

    for (int i = 0; i < _Loop; ++i)
    {
        float density = densityFunction(localPos);

        if (density > 0.0)
        {
            float d = density * step;
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

        localPos += localStep;

        if (!all(max(0.5 - abs(localPos), 0.0))) break;
    }

    color.a = min(color.a, 1.0);

    return color;
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
    ENDCG
}

}

}