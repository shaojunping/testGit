// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

///Update 16.12.22 :Force sample tilling in VS to avoid nmap flicker!!
///Update 17.2.15 modify horizon UV
Shader "TSHD/WaterMobileHQ_All_NewDeepShallow"
{
	Properties
	{
		//[NoScaleOffset]_WaterBumpTex ("Normal Map (RGB)", 2D) = "white" {}
		_ShallowColor ("Shallow Color", Color) = (1,1,1,1)
		_DeepColor ("Deep Color", Color) = (0,0,0,0)
		_DepthFactor ("Depth Factor", Range(0, 1)) = 0.5
	}


	SubShader
	{
		Pass
		{
			Tags { "Queue" = "Transparent-10" "IgnoreProjector"="True" "RenderType"="Opaque" }

			CGPROGRAM
			#include "UnityCG.cginc"
			#pragma multi_compile_fog
			
			#pragma vertex vert
			#pragma fragment frag

			float	  _DepthFactor ;
			//float _TransparentFactor;

			// CameraDepth
			sampler2D_float _LastCameraDepthTexture;

			half4 _ShallowColor;
			half4 _DeepColor;
			//sampler2D _WaterBumpTex;
			//samplerCUBE _Cube;
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
				float4 uv		: TEXCOORD0;
				// 用于切线空间的计算
				float4 TtoW0 : TEXCOORD1;  
				float4 TtoW1 : TEXCOORD2;  
				float4 TtoW2 : TEXCOORD3;
				UNITY_FOG_COORDS(4)
				// 屏幕位置
				float4 screenPos : TEXCOORD5;
				// 用于修复GrasTexture反向问题
				float4 uvgrab : TEXCOORD6;
			};

			v2f vert(a2v v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f,o);
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

				//float3 worldPos = mul (unity_ObjectToWorld, v.vertex).xyz;
				//fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				//fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				//fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

				//// 转到切线空间
				//o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				//o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				//o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				// 屏幕位置
				o.screenPos = ComputeScreenPos(o.pos);
				// grabUV
				o.uvgrab = ComputeGrabScreenPos(o.pos);
				UNITY_TRANSFER_FOG(o,o.pos);
				return o;
			}

			fixed4 frag(v2f i):SV_Target 
			{
				float  sceneZ		= LinearEyeDepth (tex2Dproj(_LastCameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)).r);
				float  objectZ		= i.screenPos.z;
				// 通过深度混合扭曲后的GrapTexture
				fixed depthFactor   = saturate((sceneZ - objectZ))*_DepthFactor;
				//fixed3 shallowColor = lerp();
				fixed3 finalColor	= lerp(_ShallowColor, _DeepColor, depthFactor);

				//float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				//half3 viewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				//float transparentFactor = _TransparentFactor * depthFactor;
				//return fixed4(finalColor, 1);
				//finalColor = grabColor;
				//finalColor = lerp(grapColor, finalColor, transparentFactor);
				//finalColor = fixed3(depthFactor, depthFactor, depthFactor);
				return fixed4(finalColor, 1);
			}
			ENDCG
		}
	}
	
	FallBack "Legacy Shaders/Transparent/VertexLit"
}
