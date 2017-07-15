// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
Shader "TSHD/Water_CusDepthOcean"
{
	Properties 
	{
		// WaveNormalMap
		[NoScaleOffset] _WaveMap ("Wave Normal Map", 2D) = "bump" {}
		_Tiling 	("Tiling", Range(10, 200)) = 40
		_WaveXSpeed ("Wave X Speed", Range(-1, 1)) = 0.1
		_WaveYSpeed ("Wave Y Speed", Range(-1, 1)) = 0.1
		_WaveBumpSpeed ("Wave Bump Speed", Range(-1, 1)) = 0.5
		_WaveZIntensity  ("Bump Scale factor", Range (0,2)) = 1.0
		_WaveWind("Wave Wind",Range(0,2)) =0.5
		_WaveHeight("Wave Height",Range(0,2)) =0.5
		_Frequency("Wave Frequency",Range(0,2)) = 0.5

		// EdgeAndFoam
		[NoScaleOffset] _Foam ("Foam texture", 2D) = "white" {}
		[NoScaleOffset] _FoamGradient ("Foam gradient ", 2D) = "white" {}
		_FoamTiling  ("Foam Tiling", Range (0.01,1)) = 1.0
		_FoamFactor ("Foam Factor", Range (0, 5.0)) = 1.0
		_FoamMultipiler ("Foam Multipiler", Range (0, 10.0)) = 2.0
		
		// Color
		_Color0  ("Color1", COLOR)  = (0.509,0.862,0.960,1)
		_Color1  ("Color2", COLOR)  = (0.058,0.058,0.137,1)

		// CubeMap
		_Cubemap ("Cubemap", Cube) = "_Skybox" {}
		_CubemapInstensity ("Cubemap Intensity", Range(0.1,1)) = 0.5
		
		// 
		_DepthFactor ("Depth Factor", Float) = 5
		_DistortionFactor ("Distortion", Range(0, 100)) = 50
		
	}
	SubShader 
	{

		//Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Opaque" }

		GrabPass { "_GrabTexture" }
		
		Pass
		{
			Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Opaque" }
			//Cull Back	
			CGPROGRAM
			
			#include "UnityCG.cginc"
			#pragma multi_compile_fog
			
			#pragma vertex vert
			#pragma fragment frag
			
			// GrasPassTexture
			sampler2D _GrabTexture;
			float4	  _GrabTexture_TexelSize;
			
			// CameraDepth
			sampler2D_float _LastCameraDepthTexture; 
			
			// 波动图以及Tiling,Speed
			sampler2D _WaveMap;
			fixed _Tiling;

			fixed _WaveXSpeed;
			fixed _WaveYSpeed;
			
			fixed _WaveZIntensity;
			
			half _WaveWind,_WaveHeight,_Frequency,_WaveBumpSpeed;

			// 边缘泡沫的贴图以及Tiling
			sampler2D _Foam;
			sampler2D _FoamGradient;
			
			fixed _FoamTiling;
			fixed _FoamFactor;
			
			fixed _FoamMultipiler;
			
			// 两个基本颜色
			fixed4 _Color0;
			fixed4 _Color1;
			
			// CubeMap
			samplerCUBE _Cubemap;
			fixed _DepthFactor;
			fixed _DistortionFactor;	
			fixed _CubemapInstensity;

			struct a2v 
			{
				float4 vertex	: POSITION;
				float3 normal	: NORMAL;
				float4 tangent	: TANGENT; 
				float4 texcoord : TEXCOORD0;
				
			};
			
			struct v2f
			{
				float4 pos		: SV_POSITION;
				float4 uv		: TEXCOORD0;
				// 用于切线空间的计算
				float4 TtoW0 : TEXCOORD1;  
				float4 TtoW1 : TEXCOORD2;  
				float4 TtoW2 : TEXCOORD3; 
				UNITY_FOG_COORDS(4)
				// 屏幕位置
				float4 scrPos : TEXCOORD5;
				// 用于修复GrasTexture反向问题
				float4 uvgrab : TEXCOORD6;
				
			};
			
			v2f vert(a2v v) 
			{
				v2f o;

				float4 pos =v.vertex;
				half animTimeX = _Time.w * _WaveXSpeed;
				half animTimeY =_Time.w * _WaveYSpeed;
				half waveXcos = sin(animTimeX +v.vertex.x *_Frequency)*_WaveWind;
				half waveYcos = sin(animTimeY +v.vertex.z *_Frequency)*_WaveHeight; 
				pos.x +=waveXcos;
				pos.z +=waveXcos ;
				pos.y +=waveYcos ;

				o.pos = mul(UNITY_MATRIX_MVP, pos);
				//o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

				// Normal的UV放在了zw里面，边缘泡沫的UV放在了xy里面
				float4 wpos = mul (unity_ObjectToWorld, v.vertex);
				o.uv.zw = wpos.xz / fixed2(_Tiling,_Tiling);
				o.uv.xy = _FoamTiling * wpos.xz + 0.05 * float2(_SinTime.w, _SinTime.w);
				
				// 世界位置，法线，切线，副法线
				float3 worldPos 		= mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal		= UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent 	= UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal	= cross(worldNormal, worldTangent) * v.tangent.w; 
				
				// 转到切线空间
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				// 屏幕位置
				o.scrPos = ComputeScreenPos(o.pos);
				// grabUV
				o.uvgrab =ComputeGrabScreenPos(o.pos);

				UNITY_TRANSFER_FOG(o,o.pos);
				return o;
				
			}
			
			fixed4 frag(v2f i) : SV_Target 
			{
				// 世界位置
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);

				// 视图向量
				half3 viewDir	= normalize(UnityWorldSpaceViewDir(worldPos));
				
				// UV动画速度
				//_WaveBumpSpeed
				//float2 speed	= _Time.y* float2(_WaveXSpeed, _WaveYSpeed)*0.2 ;
				half speed	= _Time.x* _WaveBumpSpeed;
				
				// 合并水波动画
				half4 bump1	= tex2D(_WaveMap, i.uv.zw + half2(speed,speed));
				half4 bump2	= tex2D(_WaveMap, i.uv.zw - half2(speed,speed));
				half3 bump 	= UnpackNormal((bump1 + bump2)*0.5).rgb * half3(_WaveZIntensity,_WaveZIntensity,1);
	
				// 用GrapTexture+offset做扭曲
				// 目前重新计算grabTextureUV来修复反向问题
				i.uvgrab.xy += bump.xy * _DistortionFactor  * i.uvgrab.w * _GrabTexture_TexelSize.xy;
				fixed3 grapColor = tex2Dproj( _GrabTexture, UNITY_PROJ_COORD(i.uvgrab));

				// Normal转换到世界空间
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));

				// 最基本的颜色通过Fresnel来混合两个基本颜色
				fixed  fresnel		= pow(saturate(dot(viewDir, bump)), 0.3);
				fixed3 finalColor	= lerp(_Color0,_Color1,fresnel);
	
				// 边缘查找				
				float sceneZ		= LinearEyeDepth (tex2Dproj(_LastCameraDepthTexture, UNITY_PROJ_COORD(i.scrPos)).r);
				float objectZ		= i.scrPos.z;
				float intensityFactor = 1 - saturate((sceneZ - objectZ) / _FoamFactor);  
						
				// 泡沫UV动画
				half3 foamGradient	= 1 - tex2D(_FoamGradient, float2(intensityFactor - _Time.y*0.1, 0) + bump.xy * 0.15);
				half2 foamDistortUV = bump.xy * 0.2;
				//half3 foamColor 	= tex2D(_Foam, i.uv.xy + foamDistortUV).rgb;
				half3 foamColor 	= tex2D(_Foam, foamDistortUV).rgb;

				finalColor			+= foamGradient * (intensityFactor * 3) * foamColor * _FoamMultipiler;

				// 通过深度混合扭曲后的GrapTexture
				fixed depthFactor   = saturate((sceneZ - objectZ) / _DepthFactor);//saturate(objectZ / _DepthFactor);
				finalColor			= lerp(grapColor,finalColor,depthFactor);

				// 最后添加CubeMap的部分，通过Fresnel来混合
				fixed3 reflDir		= reflect(-viewDir, bump);
				fixed3 reflCol		= texCUBE(_Cubemap, reflDir).rgb;

				fixed fresnelCube	= pow(1 - saturate(dot(viewDir, bump)), 10);
				//finalColor			= (reflCol * fresnelCube) + (finalColor * (1 - fresnelCube));
				fixed3 cubeMapAvg   = lerp(_Color0,reflCol,_CubemapInstensity);
				finalColor			= lerp(cubeMapAvg,finalColor,(1-fresnelCube));//(reflCol * fresnelCube) + (finalColor * (1 - fresnelCube));

				// Fog
				UNITY_APPLY_FOG(i.fogCoord, finalColor);
				return fixed4(finalColor, 1);
				
			}
			
			ENDCG
		}
	}
	//FallBack Off
}
