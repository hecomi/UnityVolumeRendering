Shader "Intersection"
{

Properties
{
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

v2f vert(appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    return o;
}

float4 frag(v2f i) : SV_Target
{
    // ワールド空間でのポリゴン表面座標とそこへのカメラからの向き
    float3 worldPos = i.worldPos;
    float3 worldDir = normalize(worldPos - _WorldSpaceCameraPos);

    // オブジェクト空間に変換
    float3 localPos = mul(unity_WorldToObject, float4(worldPos, 1.0));
    float3 localDir = UnityWorldToObjectDir(worldDir);

    // レイが突き抜けるまでの長さ
    float3 invLocalDir = 1.0 / localDir;
    float3 t1 = (-0.5 - localPos) * invLocalDir;
    float3 t2 = (+0.5 - localPos) * invLocalDir;
    float3 tmax3 = max(t1, t2);
    float2 tmax2 = min(tmax3.xx, tmax3.yz);
    float traverseDist = min(tmax2.x, tmax2.y);

    // 0 ~ 1 で赤、1 ~ で黄色になるように調整
    float f = frac(traverseDist);
    float r = min(traverseDist, 1.0);
    float g = max(traverseDist - r, 0.0);
    return float4(r, g, 0.0, 1.0);
}

ENDCG

SubShader
{

Tags 
{ 
    "Queue" = "Geometry"
    "RenderType" = "Opaque" 
}

Pass
{
    CGPROGRAM
    #pragma vertex vert
    #pragma fragment frag
    ENDCG
}

}

}