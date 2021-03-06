// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

///Update 16.12.22 :Force sample tilling in VS to avoid nmap flicker!!
///Update 17.2.15 modify horizon UV
Shader "TSHD/WaterMobileHQ_All_NewDeepShallow"
{
	Properties
	{
		[NoScaleOffset]_WaterTex ("Normal Map (RGB), Foam (A)", 2D) = "white" {}
		[NoScaleOffset]_FoamTex ("Foam Map (RGB)", 2D) = "black" {}
		_Cube ("Skybox", Cube) = "_Skybox" { }
		_ShallowColor ("Shallow Color", Color) = (1,1,1,1)
		_DeepColor ("Deep Color", Color) = (0,0,0,0)
		_OffsetSpeedX("Offset SpeedX",float) =1.0
		_OffsetSpeedY("Offset SpeedY",float) =1.0
		_Tiling ("Normal Tiling", Range(0.025, 0.2)) = 0.025
		_FoamTiling ("Foam Tiling", Range(0.025, 0.2)) = 0.025
		_Specular ("Specular", Color) = (0,0,0,0)
		_SpeScale("Specular Scale",float) =1.0
		_Shininess ("Shininess", Range(0.01, 1.0)) = 1.0
		_lightDir ("Light Dir(XYZ)", Vector) = (1.0, 1.0, 1.0, 1.0)
		_ReflectionTint ("Reflection Tint", Range(0.0, 1.0)) = 0.8
		_WaveWindSpeed ("Wave Wind Speed", Range(-1, 1)) = 0.1
		_WaveHeightSpeed ("Wave Height Speed", Range(-1, 1)) = 0.1
		_WaveWindScale("Wave Wind Scale",Range(0, 0.01)) = 0.003
		_WaveHeightScale("Wave Height Scale",Range(0, 0.01)) =0.005
		_DepthFactor("DepthFactor",Range(0, 2)) =0.8
		_AlphaScale("Alpha Scale", Range(0, 1)) = 0.4
		_LightScale("Ambient Scale", Range(0, 2)) = 1
		//_InvRanges ("Alpha OffSet(X), Depth OffSet(Y) ,Alpha Scale(Z),Amb Scale(W)", Vector) = (0.0, 0.5, 1.0, 1.0)
	}

	SubShader
	{
		//LOD 300
		Pass
		{
			Tags { "Queue" = "Transparent" "IgnoreProjector"="True" "RenderType"="Opaque" }

			//ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma multi_compile_fog
			
			#pragma vertex vert
			#pragma fragment frag

			float	  _DepthFactor;
			fixed	  _Tiling;
			fixed	  _FoamTiling;
			//float _TransparentFactor;

			// CameraDepth
			sampler2D_float _LastCameraDepthTexture;
			sampler2D _WaterTex;
			sampler2D _FoamTex;
			//float4    _WaterTex_ST;
			//float4    _FoamTex_ST;
			samplerCUBE _Cube;

			//sampler2D _NoiseTex;

			fixed4 _ShallowColor;
			fixed4 _DeepColor;
			half _OffsetSpeedX;
			half _OffsetSpeedY;
			
			half4 _Specular;
			half _SpeScale;
			float _Shininess;
			half4 _lightDir;
			half4 _InvRanges;
			half _ReflectionTint;

			fixed _WaveWindSpeed;
			fixed _WaveHeightSpeed;
			half  _WaveWindScale;
			half  _WaveHeightScale;

			float _AlphaScale;
			float _LightScale;
			//float _DepthFactor;

			struct a2v
			{
				float4 vertex		:POSITION;
				float3 normal		:NORMAL;
				float4 tangent		:TANGENT;
				float4 texcoord		:TEXCOORD0;
			};

			struct v2f
			{
				float4 pos		: SV_POSITION;
				float3 worldPos : TEXCOORD1;
				float4 tilings	: TEXCOORD0;    //xy for for normal, zw for foam
				// 用于切线空间的计算
				//float4 TtoW0 : TEXCOORD1;  
				//float4 TtoW1 : TEXCOORD2;  
				//float4 TtoW2 : TEXCOORD3;
				UNITY_FOG_COORDS(3)
				// 屏幕位置
				float4 screenPos	  : TEXCOORD2;
				float4 foamTilings    : TEXCOORD4;
			};

			v2f vert(a2v v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				float4 pos = v.vertex;
				float waveOffset = sin(_Time.w * _WaveWindSpeed + pos.x * 0.1) * _WaveWindScale;
				float waveHeightOffset = sin(_Time.w * _WaveHeightSpeed + pos.z * 0.1) * _WaveHeightScale;
				
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				// 屏幕位置
				o.screenPos = ComputeScreenPos(o.pos);

				float offsetX = frac( _Time.x *_OffsetSpeedX);
				half2 tiling = o.worldPos.xz * _Tiling;
				o.tilings.xy = tiling + offsetX;
				float offsetY = frac( _Time.x *_OffsetSpeedY);
				o.tilings.zw = half2(-tiling.y, tiling.x) - offsetY;

				//float offsetX = frac( _Time.x *_OffsetSpeedX);
				half2 foamTiling = o.worldPos.xz * _FoamTiling;
				o.foamTilings.xy = foamTiling + offsetX;
				//float offsetY = frac( _Time.x *_OffsetSpeedY);
				o.foamTilings.zw = half2(-foamTiling.y, foamTiling.x) - offsetY;
				return o;
			}

			fixed4 frag(v2f i):SV_Target 
			{
				float  sceneZ		= LinearEyeDepth (tex2Dproj(_LastCameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)).r);
				float  objectZ		= i.screenPos.z;

				fixed depthFactor   = abs(sceneZ - objectZ) * _DepthFactor;// ;
				fixed3 albedo	= lerp(_ShallowColor, _DeepColor, depthFactor);
				half alpha = _AlphaScale;
				//return fixed4(albedo, 1);
				// 世界位置
				float3 worldView = i.worldPos - _WorldSpaceCameraPos;

				//half4 noise = tex2D(_NoiseTex, i.tilings.xy);
				half4 foam = tex2D(_FoamTex, i.foamTilings.zw + i.foamTilings.xy);
				// Calculate the object-space normal (Z-up)
				half4 nmap = tex2D(_WaterTex, i.tilings.xy) ;//+ tex2D(_WaterTex, i.tilings.zw);
				half4 nmap2 = tex2D(_WaterTex, i.tilings.zw);// + tex2D(_WaterTex, i.tilings.zw);
				half3 Normal = nmap.xyz + nmap2.xyz - 1.0;
				//half3 nNormal = normalize(Normal);

				// Fake World space normal (Y-up)
				//half3 worldNormal = Normal.xzy;
				//worldNormal.z = -worldNormal.z;
				half3 nNormal = normalize(Normal);

				albedo.rgb = lerp(albedo.rgb, albedo.rgb + foam.rgb, foam.a);
				//return fixed4(albedo, 1);
				// Dot product for fresnel effect
				half fresnel = abs( dot(normalize(worldView), nNormal));
				fresnel = 1-fresnel;

				half3 reflection = texCUBE(_Cube, reflect(worldView, Normal)).rgb ;
				// Always assume 20% reflection right off the bat, and make the fresnel fade out slower so there is more refraction overall
				fresnel *= fresnel;
				fresnel = (0.8 * fresnel + 0.7) * alpha;

				albedo = lerp(albedo, reflection, _ReflectionTint);
				//albedo = lerp(albedo, albedo + foam.rgb, (1-(nmap2.a/2)) );
				//albedo = lerp(albedo, albedo + foam.rgb, foam.a );
				//return fixed4(albedo, 1);
				half3 emission = albedo * (1 - fresnel);
				albedo *= fresnel;

				half  shininess = _Shininess * 128.0;

				half3 lightDir = normalize(_lightDir.xyz);
				half diffuseFactor = abs(dot(nNormal, lightDir));
				//return fixed4(albedo , alpha);
				//half reflectiveFactor = abs(dot(worldView, reflect(lightDir, nNormal)));
				half3 h = normalize(lightDir + worldView);
				float nh = abs(dot(nNormal, h));
				half specularFactor = pow(nh, shininess) * _Specular*_SpeScale;
				//return half4(albedo, alpha);
				half4 c;
				c.rgb = (albedo * diffuseFactor + _Specular * specularFactor);
				//return fixed4(albedo.rgb * diffuseFactor, alpha);
				//return fixed4((_Specular.rgb* specularFactor), alpha);
				c.rgb *= 2 * _LightScale;
				c.a = alpha;
				return c;
				//half3 h = normalize (_lightDir.xyz + worldView);
				//half nh = max (0, dot (worldNormal, h));
				//half shininess = _Shininess * 250.0 + 4.0;
				//half spec = pow (nh, shininess);
				//finalColor += _Specular.rgb * spec;

				////float depth = abs(sceneZ - objectZ);
				////if(objectZ > sceneZ)
				////    finalColor.rgb = half3(1, 1, 1); //- foam.a*4
				////finalColor.rgb = lerp(finalColor.rgb, finalColor.rgb + foam.rgb, (1-(nmap2.a/2)) - foam.a*4 );
				////finalColor.rgb = lerp(finalColor.rgb, finalColor.rgb + foam.rgb, (1-(nmap2.a/2)) - foam.a*4 - noise.r/2);
				//return fixed4(finalColor.rgb * _LightScale, alpha);
			}
			ENDCG
		}
	}
	
	//SubShader
	//{
	//	Lod 200
	//}
	FallBack "Legacy Shaders/Transparent/VertexLit"
}
