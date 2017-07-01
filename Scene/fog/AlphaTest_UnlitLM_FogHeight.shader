// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "TSHD/AlphaTest_UnlitLM_FogHeight" {
Properties {
	_Color ("Main Color", Color) = (1,1,1,1)
	_MainTex ("Base (RGB)", 2D) = "white" {}
	_AlphaTex ("Alpha Texture (R)", 2D) = "white" {}
	_Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
	_FogVal ("Fog Density",Range(0,1)) =1.0
}

SubShader {
	Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
	LOD 100
	
	// Non-lightmapped
	Pass {
        //Tags { 
        //    "LightMode" = "Vertex"
        //     }
        Name "FORWARD"
		Tags { "LightMode" = "ForwardBase" }

		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#pragma multi_compile_fog
        #pragma multi_compile LIGHTMAP_ON LIGHTMAP_OFF

		#include "UnityCG.cginc"
		#include "Lighting.cginc"

		uniform fixed4 _Color;
		uniform float _Cutoff;
		uniform sampler2D _AlphaTex;uniform float4 _AlphaTex_ST;
		uniform sampler2D _MainTex;uniform float4 _MainTex_ST;
        uniform sampler2D _FogTex;uniform float4 _FogTex_ST;

		uniform fixed _FogVal;
        uniform float _FogHeiParaZ,_FogHeiParaW;
        uniform fixed4 _GradientFogColor;

          struct appdata_t{
			float4 vertex : POSITION;
			float2 texcoord : TEXCOORD0;
			float2 texcoord1 : TEXCOORD1;
		};
		struct v2f { 
			float4 pos :SV_POSITION;
			half2  uv : TEXCOORD0;
			float2 fogCoord : TEXCOORD1;
            #ifndef LIGHTMAP_OFF  
			    half2  lmuv : TEXCOORD2;
            #endif
		};

		v2f vert(appdata_t v)
		{
			v2f o;
			UNITY_INITIALIZE_OUTPUT(v2f,o)
			o.pos =mul(UNITY_MATRIX_MVP,v.vertex);
            float4 worldPos =mul(unity_ObjectToWorld,v.vertex);
			o.uv =TRANSFORM_TEX(v.texcoord,_MainTex);
            #ifndef LIGHTMAP_OFF  
                o.lmuv = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
            #endif
			#if defined(FOG_LINEAR)
			// factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
	            o.fogCoord.x = (o.pos.z) * unity_FogParams.z + unity_FogParams.w;
                //o.fogCoord.y =((worldPos.y -_FogHeiStart)/(_FogHeiEnd-_FogHeiStart)); //linear
                o.fogCoord.y =worldPos.y *_FogHeiParaZ +_FogHeiParaW;
			#elif defined(FOG_EXP)
				// factor = exp(-density*z)
	            o.fogCoord.x = unity_FogParams.y * (o.pos.z);
                o.fogCoord.x  = exp2(-o.fogCoord.x );
                o.fogCoord.y =worldPos.y *_FogHeiParaZ +_FogHeiParaW;
			#elif defined(FOG_EXP2)
				// factor = exp(-(density*z)^2)
	           o.fogCoord.x = unity_FogParams.x * (o.pos.z); 
               o.fogCoord.x= exp2(-o.fogCoord.x *o.fogCoord.x );
                o.fogCoord.y =worldPos.y *_FogHeiParaZ +_FogHeiParaW;
			#else
				o.fogCoord.x= 1.0;
			#endif

			return o;
		}

		fixed4 frag(v2f i) :COLOR
		{
			fixed4 c =_Color* tex2D(_MainTex,i.uv);
			fixed4 texcol = tex2D(_AlphaTex, i.uv);
			clip( texcol.r - _Cutoff );
            #ifndef LIGHTMAP_OFF  
                    fixed4 lm = UNITY_SAMPLE_TEX2D(unity_Lightmap,i.lmuv);
                    c.rgb *=DecodeLightmap(lm);
            #endif
            #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
                 half4 fogTex = tex2D(_FogTex,float2(1-i.fogCoord.x ,1-i.fogCoord.x)) ;
                fogTex.rgb *= _GradientFogColor.rgb;
                half4 fogCol = _GradientFogColor >0.01f ? fogTex : unity_FogColor  ;

			    fixed3 tempC = lerp(fogCol.rgb, c.rgb, saturate(i.fogCoord.x));
                tempC =lerp(fogCol.rgb,tempC,saturate(i.fogCoord.y));
			    c.rgb = lerp(c.rgb,tempC,_FogVal);
            #endif
			return c;
		}
		ENDCG
	}
		
	
	// Pass to render object as a shadow caster
	Pass {
		Name "Caster"
		Tags { "LightMode" = "ShadowCaster" }
		
		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#pragma multi_compile_shadowcaster
		#include "UnityCG.cginc"

		struct v2f { 
			V2F_SHADOW_CASTER;
			float2  uv : TEXCOORD1;
		};

		uniform float4 _AlphaTex_ST;

		v2f vert( appdata_base v )
		{
			v2f o;
			TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
			o.uv = TRANSFORM_TEX(v.texcoord, _AlphaTex);
			return o;
		}

		uniform sampler2D _AlphaTex;
		uniform fixed _Cutoff;
		uniform fixed4 _Color;

		float4 frag( v2f i ) : SV_Target
		{
			fixed4 texcol = tex2D(_AlphaTex, i.uv );
			clip( texcol.r*_Color.a - _Cutoff );
			
			SHADOW_CASTER_FRAGMENT(i)
		}
		ENDCG

	}
	
}
Fallback "Unlit/Transparent Cutout" 
}