// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "TSHD/Character_Dif_All"
{
	Properties
	{
        _EmissionColor ("Self-Illumination Color", Color) = (0.8,0.8,0.8,1)
		_MainTex ("Main Texture(RGB)", 2D) = "white" {}
        _AlphaTex("Alpha Textre(R)",2D) = "white" {}
        _FlowTex ("FlowMask(R) FlowTex(G) ReflectionMask Map(B)", 2D) = "black" {}
        _GlowColor ("Flow Color", Color) = (0.99,0.7,0.1,1)
        _ScrollX ("Flow U speed",Range(-2,2)) = 0.2
        _ScrollY ("Flow V speed",Range(-2,2)) = 0.2
        _FlowScale ("Flow Scale",Range(0,5)) = 2.0
        _RimColor ("Rim Color", Color) = (0.0,0.0,0.0,1.0)
		_RimPower ("Rim Power", Range(0.5,5)) = 3.0
		_RimLevel ("Rim Level",Range(0,3)) = 0.5
        _RimDir("Rim Direction(W>0 Direction Rim,or esle Full Rim)",Vector) =(1,1,0,1)

		_SpecularMap ("SpecularMap(RGB)",2D) = "white" {}
		_SpecColor ("Specular Color Tweak", Color) = (0.0, 0.0, 0.0, 1)
        _SpecScale  ("Specular Scale",Range(0.0,5.0)) = 1.0
		_SpecPower ("SpecPower",Range(0.1,60)) = 3
        _Cubemap ("Skybox", Cube) = "_Skybox" { }
        _RefMask("Reflect Mask",2D) = "black" {}
        _ReflectVal("Reflect Value",Range(0,5)) = 0.2

        // Blending state
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
        
            Blend [_SrcBlend] [_DstBlend]
	        ZWrite [_ZWrite]

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fog
			
	        // #pragma shader_feature _FLOWMAP
	        // #pragma shader_feature _SPEMAP
	        // #pragma shader_feature _REFMAP
	        // #pragma shader_feature _RIM
            #pragma shader_feature _ALPHA

            #pragma multi_compile _FLOWMAP_OFF _FLOWMAP 
            #pragma multi_compile _SPEMAP_OFF _SPEMAP
            #pragma multi_compile _REFMAP_OFF  _REFMAP
            #pragma multi_compile _RIM_OFF _RIM

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			struct v2f
			{
				float4 uvPack: TEXCOORD0;
				float4 pos : SV_POSITION;
            #ifdef _RIM
                float4 rimCol : TEXCOORD1;
            #endif
                float3 normalDir : TEXCOORD2;
                float3 lightDir : TEXCOORD3;  
              	float4 viewDirNDL : TEXCOORD4; //xyz:viewDir w:NDL
              	float4 vLihgtspe :TEXCOORD5; // xyz:ambient/SH/vertexlights w:spe
              	float3 worldPos : TEXCOORD6;
              	SHADOW_COORDS(8)
              	UNITY_FOG_COORDS(7)
			};

			sampler2D _MainTex;
            sampler2D _AlphaTex;
			float4 _MainTex_ST;
            fixed4 _EmissionColor;
            fixed4 _GlowColor;
            fixed _ScrollX;
            fixed _ScrollY;
            fixed _FlowScale;
            sampler2D _FlowTex; float4 _FlowTex_ST;

            uniform float _RimPower;
		    uniform fixed4 _RimColor;
		    uniform fixed _RimLevel;
            uniform  float4  _RimDir;

			sampler2D _SpecularMap; 
	    	float _ReflectVal;
			samplerCUBE _Cubemap;
            sampler2D _RefMask;
	    	fixed _SpecPower;
            fixed _SpecScale;
			
			v2f vert (appdata_base v)
			{
				v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f ,o);
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uvPack.xy = TRANSFORM_TEX(v.texcoord, _MainTex);

                // 把NDL放到顶点运算
			    o.lightDir  = _WorldSpaceLightPos0.xyz;
                //world  normal
                o.normalDir =UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDirNDL.xyz = normalize(UnityWorldSpaceViewDir(o.worldPos));

			    fixed3 worldViewDir = normalize(o.viewDirNDL.xyz   + o.lightDir  );
			    half ndl =dot(o.normalDir , o.lightDir );
                //N dot L 
                o.viewDirNDL.w = ndl;

            #ifdef _FLOWMAP
                o.uvPack.zw = TRANSFORM_TEX(v.texcoord, _FlowTex) +_Time*float2(_ScrollX,_ScrollY);	
            #endif
                //RIM
            #ifdef _RIM  
                half rim = 1.0f -saturate(dot(o.normalDir , o.viewDirNDL.xyz));
                half rimMask =_RimDir.w>0 ? saturate(dot(o.normalDir, _RimDir.xyz)) : 1;             

                o.rimCol =(_RimColor *pow(rim,_RimPower)) *_RimLevel*rimMask;
            #endif
                //Specular & reflect
            #ifdef _SPEMAP
                half nh = max (0, dot (o.normalDir  ,worldViewDir));
				o.vLihgtspe.w = pow (nh, _SpecPower) * _SpecScale;
            #endif
				//SH light
                //o.vLihgtspe.xyz = ShadeSH9 (float4(o.normalDir,1.0));
            //#ifdef VERTEXLIGHT_ON
            //    o.vlight += Shade4PointLights (
            //    unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            //    unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            //    unity_4LightAtten0, o.worldPos, o.normalDir  );
            //#endif 
                TRANSFER_SHADOW(o); 
				UNITY_TRANSFER_FOG(o,o.pos);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
                fixed4 tex= tex2D(_MainTex, i.uvPack.xy);
            #ifdef _ALPHA
               fixed cutA =tex2D(_AlphaTex, i.uvPack.xy).r;
               clip(cutA -0.5);
            #endif
				// Flow
            #ifdef _FLOWMAP
                fixed4 flow = tex2D(_FlowTex,i.uvPack.xy);
				tex += flow.r * tex2D(_FlowTex,i.uvPack.zw).g*_GlowColor*_FlowScale;
            #endif 
				//Ambient
                fixed4 col=tex*_EmissionColor *max(0.0,i.viewDirNDL.w) *_LightColor0 ;
                col +=tex;
                //col.rgb +=i.vLihgtspe.rgb;
                col *=_EmissionColor ;

                //Amb color
                col +=col*UNITY_LIGHTMODEL_AMBIENT;
                //RIM
            #ifdef _RIM 
                col +=i.rimCol;
            #endif 
                //Reflect
            #ifdef _REFMAP
                fixed3 worldRefl = reflect (-i.viewDirNDL.xyz  , i.normalDir); 
            	fixed3 lightRefl = reflect(-i.lightDir, i.normalDir);  
                fixed3 refM = tex2D(_RefMask,i.uvPack.xy);
            	fixed3 reflection = texCUBE(_Cubemap, worldRefl).rgb * refM.b*_ReflectVal; 
            	col.rgb +=reflection;
            #endif 
            	//Specular
            #ifdef _SPEMAP
            	UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos)
            	half4 specCol = tex2D(_SpecularMap,  i.uvPack.xy);
            	col.rgb += _LightColor0.rgb *  i.vLihgtspe.w *specCol*_SpecColor* atten;
            #endif 
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
                UNITY_OPAQUE_ALPHA(col.a);
            
				return col;
			}
			ENDCG
		}
	}
    CustomEditor "CharShaderGUI"
	FallBack "Mobile/Diffuse"
}
