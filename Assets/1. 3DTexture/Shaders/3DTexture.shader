Shader "VolumeRendering/WorldSpaceClipping"
{

Properties
{
    _Volume("Volume", 3D) = "" {}
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
    float3 uv : TEXCOORD0;
};

sampler3D _Volume;

v2f vert(appdata v)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(v.vertex);
    float4 wpos = mul(unity_ObjectToWorld, v.vertex);
    o.uv = wpos.xyz * 0.5 + 0.5;
    return o;
}

fixed4 frag(v2f i) : SV_Target
{
    return tex3D(_Volume, i.uv);
}

ENDCG

SubShader
{

Tags 
{ 
    "RenderType"="Opaque" 
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