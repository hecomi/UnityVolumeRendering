Shader "VolumeSphere"
{

Properties
{
    _Color("Color", Color) = (1, 1, 1, 1)
    _Intensity("Intensity", Range(0, 1)) = 0.1
    _Loop("Loop", Range(0, 128)) = 32
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
    float4 worldPos : TEXCOORD1;
};

float4 _Color;
float _Intensity;
int _Loop;

inline float densityFunction(float3 p)
{	
	return 0.5 - length(p);
}

v2f vert(appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    // ポリゴン表面の座標がフラグメントシェーダで使えるようにする
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    return o;
}

float4 frag(v2f i) : SV_Target
{
    // ワールド空間でのポリゴン表面座標とそこへのカメラからの向き
    float3 worldPos = i.worldPos;
    float3 worldDir = normalize(worldPos - _WorldSpaceCameraPos);

    // オブジェクト空間に変換
    float3 localPos = mul(unity_WorldToObject, worldPos);
    float3 localDir = mul(unity_WorldToObject, worldDir);

    // オブジェクト空間でのレイのステップ長
    float step = 1.0 / _Loop;
    float3 localStep = localDir * step;

    // レイを通過させて得られる透過率
    float alpha = 0.0;

    for (int i = 0; i < _Loop; ++i)
    {
        // ポリゴン中心ほど大きな値が返ってくる
        float density = densityFunction(localPos);

        // 球の外側ではマイナスの値が返ってくるのでそれを弾く
        if (density > 0.001)
        {
            // 透過率の足し合わせ
            alpha += (1.0 - alpha) * density * _Intensity;
        }

        // ステップを進める
        localPos += localStep;

        // ポリゴンの外に出たら終わり
        if (!all(max(0.5 - abs(localPos), 0.0))) break;
    }

    float4 color = _Color;
    color.a *= alpha;
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