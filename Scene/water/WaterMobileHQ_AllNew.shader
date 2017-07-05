// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

///Update 16.12.22 :Force sample tilling in VS to avoid nmap flicker!!
///Update 17.2.15 modify horizon UV
Shader "TSHD/WaterMobileHQ_All_New1"
{
	Properties
	{
		[NoScaleOffset]_WaterBumpTex ("Normal Map (RGB)", 2D) = "white" {}
		_ShallowColor ("Shallow Color", Color) = (1,1,1,1)
		_DeepColor ("Deep Color", Color) = (0,0,0,0)
		_DepthFactor ("Depth Factor", Range(0, 1)) = 0.5
		_BumpScale("Wave Z Intensity", Range(0, 2)) = 0.7
		_BumpTiling("Wave Bump Tiling", Range(10, 200)) = 40
		_Cubemap("Skybox", Cube) = "_Skybox" {}
		_ReflectColor ("Reflect Color", Color) = (1,1,1,1)
		_ReflectAmount ("Reflect Amount", Range(0.1,1)) = 0.5
		_lightDir ("Light Dir(XYZ)", Vector) = (1.0, 1.0, 1.0, 1.0)
	}


	SubShader
	{
		GrabPass { "_GrabTexture" }
		Pass
		{
			Tags { "Queue" = "Transparent-10" "IgnoreProjector"="True" "RenderType"="Opaque" }

			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma multi_compile_fog
			
			#pragma vertex vert
			#pragma fragment frag

			// GrasPassTexture
			sampler2D _GrabTexture;
			float4	  _GrabTexture_TexelSize;
			float	  _DepthFactor ;
			float     _Tiling;
			sampler2D _WaterBumpTex;
			float     _BumpScale;
			samplerCUBE  _Cubemap;
			//float _TransparentFactor;
			fixed4 _ReflectColor;
			fixed _ReflectAmount;

			// CameraDepth
			sampler2D_float _LastCameraDepthTexture;

			half4 _ShallowColor;
			half4 _DeepColor;
			half4 _lightDir;
			float _CubemapInstensity;
			//sampler2D _WaterBumpTex;
			//samplerCUBE _Cube;
			struct a2v
			{
				float4 vertex		:POSITION;
				float3 normal		:NORMAL;
				float4 texcoord		:TEXCOORD0;
			};

			struct v2f
			{
				float4 pos		: SV_POSITION;
				float4 uv		: TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				fixed3 worldNormal : TEXCOORD2;
				fixed3 worldViewDir : TEXCOORD3;
				fixed3 worldRefl : TEXCOORD4;

				UNITY_FOG_COORDS(5)
				// 屏幕位置
				float4 screenPos : TEXCOORD6;
				// 用于修复GrasTexture反向问题
				float4 uvgrab : TEXCOORD7;
			};

			v2f vert(a2v v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

				o.worldPos = mul (unity_ObjectToWorld, v.vertex).xyz;
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);
				o.worldRefl = reflect(-o.worldViewDir, o.worldNormal);

				//Normal's uv in uv.zw
				float4 wpos = mul (unity_ObjectToWorld, v.vertex);
				o.uv.zw = wpos.xz / fixed2(_Tiling,_Tiling);

				// 屏幕位置
				o.screenPos = ComputeScreenPos(o.pos);
				// grabUV
				o.uvgrab = ComputeGrabScreenPos(o.pos);
				UNITY_TRANSFER_FOG(o,o.pos);
				return o;
			}

			fixed4 frag(v2f i):SV_Target 
			{
				fixed3 grabColor	= tex2Dproj( _GrabTexture, UNITY_PROJ_COORD(i.uvgrab));
				float  sceneZ		= LinearEyeDepth (tex2Dproj(_LastCameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)).r);
				float  objectZ		= i.screenPos.z;
				// 通过深度混合扭曲后的GrapTexture
				fixed depthFactor   = saturate((sceneZ - objectZ))* _DepthFactor;
				//fixed3 shallowColor = lerp();
				fixed3 diffuse	= lerp(_ShallowColor, _DeepColor, depthFactor);

				fixed3 refractionColor = lerp(grabColor, diffuse, depthFactor);

				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));		
				fixed3 worldViewDir = normalize(i.worldViewDir);	

				// Use the reflect dir in world space to access the cubemap     
				fixed3 reflection = texCUBE(_Cubemap, i.worldRefl).rgb * _ReflectColor.rgb;

				//// Dot product for fresnel effect
				//half reflDir = reflect(viewDir, bump);
				//fixed fresnel = pow(1 - saturate(dot(viewDir, bump)), 10);
				////fresnel *=fresnel;
				////fresnel = 1-fresnel;
				////fresnel *= fresnel;
				//half3 cubemapCol = texCUBE(_Cubemap, reflDir).rgb;
				////half3 reflection = lerp(_ShallowColor, cubemapCol, _CubemapInstensity);
				//fixed3 finalColor = lerp(cubemapCol, refractionColor, 1 - fresnel);
				//finalColor = cubemapCol;
				fixed3 finalColor = lerp(reflection, refractionColor, _ReflectAmount);
				return fixed4(finalColor, 1);
			}
			ENDCG
		}
	}
	
	FallBack "Legacy Shaders/Transparent/VertexLit"
}
