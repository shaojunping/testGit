Shader "TSHD/Opaque_Unlit_Scroll2Layer" {
Properties {
	_Color ("Main Color", Color) = (1,1,1,1)
	_MainTex ("Base layer (RGB)", 2D) = "white" {}
	_DetailTex ("2nd layer (RGBA)", 2D) = "black" {}
	_ScrollX ("Base layer Scroll speed X", Float) = 1.0
	_ScrollY ("Base layer Scroll speed Y", Float) = 0.0
	_Scroll2X ("2nd layer Scroll speed X", Float) = 1.0
	_Scroll2Y ("2nd layer Scroll speed Y", Float) = 0.0
	_FogVal ("Fog Density",Range(0,1)) =1.0
}

SubShader {
	Tags { "Queue"="Geometry+10" "RenderType"="Opaque" }
	
	Lighting Off 
	ZWrite Off
	
	LOD 100
	
	Pass {
		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#pragma fragmentoption ARB_precision_hint_fastest	
		#pragma multi_compile_fog
		#include "UnityCG.cginc"
		fixed4 _Color;
		sampler2D _MainTex;
		sampler2D _DetailTex;

		float4 _MainTex_ST;
		float4 _DetailTex_ST;
	
		float _ScrollX;
		float _ScrollY;
		float _Scroll2X;
		float _Scroll2Y;

		fixed _FogVal;
	
		struct v2f {
			float4 pos : SV_POSITION;
			float2 uv : TEXCOORD0;
			float2 uv2 : TEXCOORD1;
			fixed4 color : TEXCOORD2;		
			float fogCoord : TEXCOORD3;
		};

	
		v2f vert (appdata_base v)
		{
			v2f o;
			o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
			o.uv = TRANSFORM_TEX(v.texcoord.xy,_MainTex) + frac(float2(_ScrollX, _ScrollY) * _Time);
			o.uv2 = TRANSFORM_TEX(v.texcoord.xy,_DetailTex) + frac(float2(_Scroll2X, _Scroll2Y) * _Time);
			o.color = _Color;
			#if defined(FOG_LINEAR)
	        // factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
	        o.fogCoord = (o.pos.z) * unity_FogParams.z + unity_FogParams.w;
            #elif defined(FOG_EXP)
	            // factor = exp(-density*z)
	            o.fogCoord = unity_FogParams.y * (o.pos.z);
                o.fogCoord  = exp2(-o.fogCoord );
            #elif defined(FOG_EXP2)
	            // factor = exp(-(density*z)^2)
	           o.fogCoord = unity_FogParams.x * (o.pos.z); 
               unityFogFactor = exp2(-o.fogCoord *o.fogCoord );
            #else
	        o.fogCoord= 1.0;
            #endif
            //UNITY_CALC_FOG_FACTOR(o.pos.z);
            //o.fogCoord = unityFogFactor;
			return o;
		}

	
		fixed4 frag (v2f i) : COLOR
		{
			fixed4 o;
			fixed4 tex = tex2D (_MainTex, i.uv);
			fixed4 tex2 = tex2D (_DetailTex, i.uv2);
			o.rgb =tex.rgb*(1-tex2.a)+tex2.rgb*tex2.a;
            o.rgb *=i.color;
            //o = (tex * tex2) * i.color;
			
			fixed3 tempC = lerp(unity_FogColor.rgb, o .rgb, saturate(i.fogCoord));
			o.rgb = lerp(o.rgb,tempC,_FogVal);
			UNITY_OPAQUE_ALPHA(o.a);

			return o;
		}
		ENDCG 
	}	
}
}
