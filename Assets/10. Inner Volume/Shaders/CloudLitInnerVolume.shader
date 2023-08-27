Shader "CloudLitInnerVolume"
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
}

CGINCLUDE

#include "UnityCG.cginc"

struct appdata
{
    float4 vertex : POSITION;
};

struct v2f
{
    float4 vertex : SV_POSITION;
    float3 worldPos : TEXCOORD1;
    float4 projPos : TEXCOORD2;
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
UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

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
        lerp(lerp(lerp(hash(n + 0.0), hash(n + 1.0), f.x),
                  lerp(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
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
    f += 0.5 * noise(p);
    p = mul(m, p) * 2.02;
    f += 0.3 * noise(p);
    p = mul(m, p) * 2.03;
    f += 0.2 * noise(p);
    return f;
}

inline float densityFunction(float3 p)
{
    return fbm(p * _NoiseScale) - length(p / _Radius);
}

inline float3 getCameraPosition()    { return UNITY_MATRIX_I_V._m03_m13_m23; }

inline float getCameraFocalLength() { return abs(UNITY_MATRIX_P[1][1]); }

inline float getCameraNearClip() { return _ProjectionParams.y; }

inline float getDistanceFromCameraToNearClipPlane(float4 projPos)
{
    projPos.xy /= projPos.w;
    projPos.xy = (projPos.xy - 0.5) * 2.0;
    projPos.x *= _ScreenParams.x / _ScreenParams.y;
    float3 norm = normalize(float3(projPos.xy, getCameraFocalLength()));
    return getCameraNearClip() / norm.z;
}

inline float3 toLocal(float3 pos)
{
    return mul(unity_WorldToObject, float4(pos, 1.0)).xyz;
}

inline float3 getScale()
{
    return float3(
        length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)),
        length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)),
        length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z)));
}

inline bool isInnerCube(float3 pos)
{
    pos = toLocal(pos);
    float3 scale = getScale(); 
    return all(max(scale * 0.5 - abs(pos), 0.0));
}

v2f vert(appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    o.projPos = ComputeScreenPos(o.vertex);
    COMPUTE_EYEDEPTH(o.projPos.z);
    return o;
}

void sample(
    float3 pos,
    float step,
    float lightStep,
    inout float4 color,
    inout float transmittance)
{
    float density = densityFunction(pos);
    if (density < 0.0) return;

    float d = density * step;
    transmittance *= 1.0 - d * _Absorption;
    if (transmittance < 0.01) return;

    float transmittanceLight = 1.0;
    float3 lightPos = pos;
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
        lightPos += lightStep;
    }

    color.a += _Color.a * (_Opacity * d * transmittance);
    color.rgb += _LightColor0 * (_OpacityLight * d * transmittance * transmittanceLight);
    color = clamp(color, 0.0, 1.0);
}

float4 frag(v2f i) : SV_Target
{
    float3 worldPos = i.worldPos;
    float3 camToWorldPos = worldPos - _WorldSpaceCameraPos;
    float3 worldDir = normalize(camToWorldPos);

    float distToNearClipPlane = getDistanceFromCameraToNearClipPlane(i.projPos);
    float3 cameraNearPlanePos = getCameraPosition() + distToNearClipPlane * worldDir;
    if (isInnerCube(cameraNearPlanePos))
    {
        worldPos = cameraNearPlanePos;
    }

    float3 localPos = mul(unity_WorldToObject, float4(worldPos, 1.0));
    float3 localDir = UnityWorldToObjectDir(worldDir);
    float3 localStep = localDir * _Step;
    localPos += (_Step - fmod(length(UnityWorldToObjectDir(camToWorldPos)), _Step)) * localDir;
    float jitter = hash(localPos.x + localPos.y * 1000 + localPos.z * 10000 + _Time.x);
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

    float depth = LinearEyeDepth(
        SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
    float3 cameraForward = -UNITY_MATRIX_V[2].xyz;
    float cameraToDepth = depth / dot(worldDir, cameraForward);
    float cameraToStart = length(worldPos - _WorldSpaceCameraPos);
    float maxLen = cameraToDepth - cameraToStart;
    if (maxLen < 0.f) discard;
    
    float len = 0.f;

    float4 color = float4(_Color.rgb, 0.0);
    float transmittance = 1.0;

    for (int i = 0; i < loop; ++i)
    {
        sample(localPos, _Step, localLightStep, color, transmittance);

        len += _Step;
        if (len > maxLen) break;

        localPos += localStep;
    }

    if (len > maxLen)
    {
        float step = maxLen - (len - _Step);
        localPos += step * localDir;
        sample(localPos, step, lightStep, color, transmittance);
    }

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
        Cull Off
        ZWrite Off
        ZTest Off
        Blend SrcAlpha OneMinusSrcAlpha

        CGPROGRAM
        #pragma vertex vert
        #pragma fragment frag
        ENDCG
    }
}

}