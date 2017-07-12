// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

///Update 16.12.22 :Force sample tilling in VS to avoid nmap flicker!!
///Update 17.2.15 modify horizon UV
Shader "TSHD/WaterMobileHQ_All_NewDeepShallow"
{
	Properties
	{
		_WaterTex ("Normal Map (RGB), Foam (A)", 2D) = "white" {}
		_FoamTex ("Foam Map (RGB)", 2D) = "black" {}
		_Cube ("Skybox", Cube) = "_Skybox" { }
		//_NoiseTex ("Noise Map (RGB)", 2D) = "black" {}
		_ShallowColor ("Shallow Color", Color) = (1,1,1,1)
		_DeepColor ("Deep Color", Color) = (0,0,0,0)
		//_DepthFactor ("Depth Factor", Range(0, 6)) = 0.5
		_OffsetSpeed("Offset Speed",float) =1.0
		_Tiling ("Tiling", Range(0.025, 0.5)) = 0.025
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
			//float _TransparentFactor;

			// CameraDepth
			sampler2D_float _LastCameraDepthTexture;
			sampler2D _WaterTex;
			sampler2D _FoamTex;
			samplerCUBE _Cube;

			//sampler2D _NoiseTex;

			half4 _ShallowColor;
			half4 _DeepColor;
			fixed _OffsetSpeed;
			
			half4 _Specular;
			fixed _SpeScale;
			float _Shininess;
			half4 _lightDir;
			half4 _InvRanges;
			float _ReflectionTint;

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
				float4 tilings	: TEXCOORD0;
				// 用于切线空间的计算
				//float4 TtoW0 : TEXCOORD1;  
				//float4 TtoW1 : TEXCOORD2;  
				//float4 TtoW2 : TEXCOORD3;
				UNITY_FOG_COORDS(3)
				// 屏幕位置
				float4 screenPos : TEXCOORD2;
			};

			v2f vert(a2v v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				float4 pos = v.vertex;
				float waveOffset = sin(_Time.w * _WaveWindSpeed + pos.x * 0.1) * _WaveWindScale;
				float waveHeightOffset = sin(_Time.w * _WaveHeightSpeed + pos.z * 0.1) * _WaveHeightScale;
				//v.vertex.x += waveOffset;
				//v.vertex.y += waveHeightOffset;
				//v.vertex.z += waveHeightOffset;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);

				//float3 worldPos = mul (unity_ObjectToWorld, v.vertex).xyz;
				//fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
				//fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				//fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

				//// 转到切线空间
				//o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				//o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				//o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z); 
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				// 屏幕位置
				o.screenPos = ComputeScreenPos(o.pos);

				float offset = frac(_Time.x * 0.5* _OffsetSpeed);
				fixed2 tiling = o.worldPos.xz * _Tiling;
				o.tilings.xy = tiling + offset; //
				o.tilings.zw = fixed2(-tiling.y, tiling.x) - offset;

				return o;
			}

			fixed4 frag(v2f i):SV_Target 
			{
				float  sceneZ		= LinearEyeDepth (tex2Dproj(_LastCameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)).r);
				float  objectZ		= i.screenPos.z;

				fixed depthFactor   = saturate(abs(sceneZ - objectZ))* _DepthFactor;// ;
				fixed3 albedo	= lerp(_ShallowColor, _DeepColor, depthFactor);
				half alpha = saturate(_AlphaScale);
				//return fixed4(albedo, 1);
				// 世界位置
				float3 worldView = i.worldPos - _WorldSpaceCameraPos;

				//half4 noise = tex2D(_NoiseTex, i.tilings.xy);
				half4 foam = tex2D(_FoamTex, i.tilings.zw);
				// Calculate the object-space normal (Z-up)
				half4 nmap = tex2D(_WaterTex, i.tilings.xy) ;//+ tex2D(_WaterTex, i.tilings.zw);
				half4 nmap2 = tex2D(_WaterTex, i.tilings.zw);// + tex2D(_WaterTex, i.tilings.zw);
				half3 Normal = nmap.xyz + nmap2.xyz - 1.0;
				//half3 nNormal = normalize(Normal);

				// Fake World space normal (Y-up)
				half3 worldNormal = Normal.xzy;
				worldNormal.z = -worldNormal.z;

				albedo.rgb = lerp(albedo.rgb, albedo.rgb + foam.rgb, nmap2.a);
				//return fixed4(albedo, 1);
				// Dot product for fresnel effect
				half fresnel =saturate( dot(-normalize(worldView), worldNormal));
				//fresnel *=fresnel;
				fresnel = 1-fresnel;

				half3 reflection = texCUBE(_Cube, reflect(worldView, worldNormal)).rgb ;
				// Always assume 20% reflection right off the bat, and make the fresnel fade out slower so there is more refraction overall
				fresnel *= fresnel;
				fresnel = (0.8 * fresnel + 0.7) * alpha;

				albedo = lerp(albedo, reflection, _ReflectionTint);
				//return fixed4(albedo, 1);
				half3 emission = albedo * (1 - fresnel);
				albedo *= fresnel;

				half3 nNormal = normalize(Normal);
				half  shininess = _Shininess * 128.0 + 4.0;

				half3 lightDir = normalize(_lightDir.xyz);
				//half diffuseFactor = max(0.0, dot(nNormal, -lightDir));
				//return fixed4(albedo , alpha);
				half reflectiveFactor = max(0.0, dot(-worldView, reflect(lightDir, nNormal)));
				half specularFactor = pow(reflectiveFactor, shininess) * _Specular*_SpeScale;

				half4 c;
				c.rgb = (albedo /** diffuseFactor*/ + _Specular * specularFactor);
				//return fixed4(c.rgb, alpha);
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
	
	FallBack "Legacy Shaders/Transparent/VertexLit"
}
