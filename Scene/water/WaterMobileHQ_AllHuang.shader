// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

///Update 16.12.22 :Force sample tilling in VS to avoid nmap flicker!!
///Update 17.2.15 modify horizon UV
Shader "TSHD/WaterMobileHQ_All"
{
	Properties
	{
		_WaterTex ("Normal Map (RGB)", 2D) = "white" {}
        //_RefractTex ("Refract Map",2D) ="white" {}
        _MainTex ("WaterMap Deep(R),Alpha (G)", 2D) = "white" {}
		_Cube ("Skybox", Cube) = "_Skybox" { }
		_Color ("Shallow Color", Color) = (1,1,1,1)
		_Color1 ("Deep Color", Color) = (0,0,0,0)
		_Specular ("Specular", Color) = (0,0,0,0)
        _OffsetSpeed("Offset Speed",float) =1.0
        _SpeScale("Specular Scale",float) =1.0

		_Shininess ("Shininess", Range(0.01, 1.0)) = 1.0
		_Tiling ("Tiling", Range(0.025, 0.5)) = 0.025
		_ReflectionTint ("Reflection Tint", Range(0.0, 1.0)) = 0.8
		_InvRanges ("Alpha OffSet(X), Depth OffSet(Y) ,Alpha Scale(Z),Amb Scale(W)", Vector) = (0.0, 0.5, 1.0, 1.0)
        _lightDir ("Light Dir(XYZ)", Vector) = (1.0, 1.0, 1.0, 1.0)
	}

	CGINCLUDE

	#include "UnityCG.cginc"
	
	half4 _Color;
	half4 _Color1;
	half4 _Specular;
	float _Shininess;
	float _Tiling;
	float _ReflectionTint;
	half4 _InvRanges;
    fixed _SpeScale;
	half4 _lightDir;
    //sampler2D_float _CameraDepthTexture;
	sampler2D _WaterTex;

	half4 LightingPPL (SurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
	{
        half3 nNormal = normalize(s.Normal);
        half shininess = s.Gloss * 250.0 + 4.0;
	
    //#ifndef USING_DIRECTIONAL_LIGHT
    //    lightDir = normalize(lightDir);
    //#endif
         lightDir =normalize(_lightDir.xyz);
        // Phong shading model      
        half reflectiveFactor = max(0.0, dot(-viewDir, reflect(lightDir, nNormal)));
	
        half diffuseFactor = max(0.0, dot(nNormal, lightDir));
        half specularFactor = pow(reflectiveFactor, shininess) * s.Specular*_SpeScale;
	
        half4 c;
        //c.rgb = (s.Albedo * diffuseFactor + _Specular.rgb * specularFactor) * _LightColor0.rgb;
        c.rgb = (s.Albedo * diffuseFactor + _Specular.rgb * specularFactor) ;
        //c.rgb *= (atten * 2.0)*_InvRanges.w;
        c.rgb *= 2*_InvRanges.w;
        c.a = s.Alpha;

		return c;
	}
	ENDCG

	SubShader
	{
   //depth soft edge,RT refraction
		Lod 300
		Tags { "Queue" = "Transparent-10" }

        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

		CGPROGRAM
		#pragma surface surf PPL vertex:vert noambient nolightmap nometa noforwardadd exclude_path:deferred exclude_path:prepass alpha:blend
        #pragma target 3.0
        //#pragma multi_compile _CUSTOMDEPTH_OFF  _CUSTOMDEPTH
        fixed _OffsetSpeed;
        samplerCUBE _Cube;
//#ifdef  _CUSTOMDEPTH_OFF
//        sampler2D _CameraDepthTexture;
//#endif

//#ifdef   _CUSTOMDEPTH
        sampler2D_float _LastCameraDepthTexture;
//#endif

        uniform sampler2D _MainTex;
        uniform sampler2D _RefractTex;
        uniform half4 _RefractTex_TexelSize;
		struct Input
		{
			float4 position  : POSITION;
             //float2 uv_MainTex;
			float3 worldPos  : TEXCOORD2;	// Used to calculate the texture UVs and world view vector
			float4 proj0   	 : TEXCOORD3;	// Used for depth and reflection textures
            //float4 proj1	 : TEXCOORD4;	// Used for the refraction texture
            float4 screenPos : TEXCOORD4;
            //float3 worldNormal;
            //INTERNAL_DATA 
            float4 tilings :TEXCOORD0;
		};
		
		void vert (inout appdata_full v, out Input o)
		{
            UNITY_INITIALIZE_OUTPUT(Input,o);
            o.worldPos =mul(unity_ObjectToWorld, v.vertex).xyz;
			o.position = mul(UNITY_MATRIX_MVP, v.vertex);
			o.proj0 = ComputeScreenPos(o.position); 
			COMPUTE_EYEDEPTH(o.proj0.z); //we get eye space depth
            
            o.screenPos =ComputeGrabScreenPos(o.position);
            float offset = frac( _Time.x *_OffsetSpeed);
            half2 tiling = o.worldPos.xz * _Tiling;
            o.tilings.xy = tiling + offset;
            o.tilings.zw = half2(-tiling.y, tiling.x) - offset;
		}
		
		void surf (Input IN, inout SurfaceOutput o)
		{
			// Calculate the world-space view direction (Y-up)
			// We can't use IN.viewDir because it takes the object's rotation into account, and the water should not.
			float3 worldView = IN.worldPos - _WorldSpaceCameraPos;
			
			// Calculate the object-space normal (Z-up)
            half4 nmap = tex2D(_WaterTex, IN.tilings.xy) + tex2D(_WaterTex, IN.tilings.zw);
			o.Normal = nmap.xyz - 1.0;

			// Fake World space normal (Y-up)
            half3 worldNormal = o.Normal.xzy;
            worldNormal.z = -worldNormal.z;
            //half3 worldNormal =IN.worldNormal;
			// Calculate the depth difference at the current pixel
            //Most Important!!!!!
            half4 projTC = UNITY_PROJ_COORD(IN.proj0);
//#ifdef  _CUSTOMDEPTH_OFF
//            float depth = tex2Dproj(_CameraDepthTexture, projTC).r;  
//#endif

//#ifdef   _CUSTOMDEPTH
            float depth = tex2Dproj(_LastCameraDepthTexture, projTC).r;     
//#endif
            //depth =min(depth,1.0f);
            depth = LinearEyeDepth(depth);
            depth -= IN.proj0.z;
////Very Important!!!!!! or else we'll get incorrect depth on Android
            depth =saturate(depth); 

            // Calculate the depth ranges (X = Alpha, Y = Color Depth)
            half3 ranges = _InvRanges.xyz * depth;
            ranges.y = saturate(1.0 - ranges.y);

            half4 col =half4(1.0,1.0,1.0,1.0) ;
            col.rgb = lerp(_Color1.rgb, _Color.rgb, ranges.y);
            col.a = saturate(ranges.z +ranges.x);

            o.Alpha = col.a;
            o.Specular = col.a;
            o.Gloss = _Shininess;

            // Dot product for fresnel effect
            half fresnel =saturate( dot(-normalize(worldView), worldNormal));
            //fresnel *=fresnel;
            fresnel = 1-fresnel;

            //we use refract tex instead of grab pass tex
            IN.screenPos.xy += o.Normal.xy * _RefractTex_TexelSize.xy * (20.0 * IN.screenPos.z * col.a);
            half3 refraction = tex2Dproj(_RefractTex,UNITY_PROJ_COORD(IN.screenPos)).rgb;
            
            refraction = lerp(refraction * col.rgb, refraction, ranges.y);
            half3 reflection = texCUBE(_Cube, reflect(worldView, worldNormal)).rgb * _ReflectionTint;
            // Always assume 20% reflection right off the bat, and make the fresnel fade out slower so there is more refraction overall
            fresnel *= fresnel;
            fresnel = (0.8 * fresnel + 0.2) * col.a;

            o.Albedo = lerp(refraction, reflection, fresnel *0.8);
            // Calculate the amount of illumination that the pixel has received already
            o.Emission = o.Albedo * (1.0 - fresnel);
		    
            // Set the final color
            o.Albedo *= fresnel;
		}
		ENDCG
	}
	
SubShader
	{
   //Tex soft edge,RT refraction
		Lod 250
		Tags { "Queue" = "Transparent-10" }

        Blend SrcAlpha OneMinusSrcAlpha
        //ZTest LEqual
		ZWrite Off

		CGPROGRAM
		#pragma surface surf PPL vertex:vert noambient nolightmap nometa noforwardadd exclude_path:deferred exclude_path:prepass alpha:blend
        #pragma target 3.0
        fixed _OffsetSpeed;
        samplerCUBE _Cube;
        
        uniform sampler2D _RefractTex;
        uniform half4 _RefractTex_TexelSize;

        uniform sampler2D _MainTex;

		struct Input
		{
			float4 position  : POSITION;
            float2 uv_MainTex;
			float3 worldPos  : TEXCOORD2;	// Used to calculate the texture UVs and world view vector
            //float4 proj0   	 : TEXCOORD3;	// Used for depth and reflection textures
            float4 screenPos : TEXCOORD4;// Used for the refraction texture
            float4 tilings :TEXCOORD3;
		};
		
		void vert (inout appdata_full v, out Input o)
		{
            UNITY_INITIALIZE_OUTPUT(Input,o);
			o.worldPos =mul(unity_ObjectToWorld, v.vertex).xyz;
			o.position = mul(UNITY_MATRIX_MVP, v.vertex);
		
            o.screenPos =ComputeGrabScreenPos(o.position);
            o.screenPos.xy = o.screenPos.xy / o.screenPos.w;

             float offset = frac( _Time.x *_OffsetSpeed);
            half2 tiling = o.worldPos.xz * _Tiling;
            o.tilings.xy = tiling + offset;
            o.tilings.zw = half2(-tiling.y, tiling.x) - offset;
		}
		
		void surf (Input IN, inout SurfaceOutput o)
		{
			// Calculate the world-space view direction (Y-up)
			// We can't use IN.viewDir because it takes the object's rotation into account, and the water should not.
			float3 worldView = (IN.worldPos - _WorldSpaceCameraPos);
			
			// Calculate the object-space normal (Z-up)
            half4 nmap = tex2D(_WaterTex, IN.tilings.xy) + tex2D(_WaterTex, IN.tilings.zw);
            o.Normal = nmap.xyz - 1.0;
			// World space normal (Y-up)
			half3 worldNormal = o.Normal.xzy;
			worldNormal.z = -worldNormal.z;
		
            float depth =tex2D(_MainTex,IN.uv_MainTex).g;
            // Calculate the depth ranges (X = Alpha, Y = Color Depth)
            half3 ranges = _InvRanges.xyz * depth;
            ranges.y = saturate(1.0 - ranges.y);

            half4 col ;
            col.rgb = lerp(_Color1.rgb, _Color.rgb, ranges.y);
            col.a = saturate(ranges.z +ranges.x);

            // Initial material properties
            o.Alpha = col.a;
            o.Specular = col.a;
            o.Gloss = _Shininess;

            half fresnel =saturate( dot(-normalize(worldView), worldNormal));
            fresnel = 1-fresnel;

            //we use refract tex instead of grab pass tex
            IN.screenPos.xy += o.Normal.xy * _RefractTex_TexelSize.xy * (20.0 * IN.screenPos.z * col.a);
            half3 refraction = tex2Dproj(_RefractTex,UNITY_PROJ_COORD(IN.screenPos)).rgb;
            refraction = lerp(refraction * col.rgb, refraction, ranges.y);
            
            half3 reflection = texCUBE(_Cube, reflect(worldView, worldNormal)).rgb * _ReflectionTint;
           //o.Emission =reflection;
           // o.Albedo =refraction;
            o.Albedo = lerp(refraction, reflection, fresnel *0.8);
            o.Emission = o.Albedo * (1.0 - fresnel);
            o.Albedo *= fresnel;
        
		}
		ENDCG
	}

SubShader
	{
   //Tex soft edge,NO refraction
		Lod 200
		Tags { "Queue" = "Transparent-10" }

        Blend SrcAlpha OneMinusSrcAlpha
        //ZTest LEqual
		ZWrite Off

		CGPROGRAM
		#pragma surface surf PPL vertex:vert noambient nolightmap nometa noforwardadd exclude_path:deferred exclude_path:prepass alpha:blend
        #pragma target 3.0
        fixed _OffsetSpeed;
        samplerCUBE _Cube;

        uniform sampler2D _RefractTex;
        uniform half4 _RefractTex_TexelSize;

        uniform sampler2D _MainTex;

		struct Input
		{
			float4 position  : POSITION;
            float2 uv_MainTex;
			float3 worldPos  : TEXCOORD2;	// Used to calculate the texture UVs and world view vector
            float4 tilings :TEXCOORD3;
		};
		
		void vert (inout appdata_full v, out Input o)
		{
            UNITY_INITIALIZE_OUTPUT(Input,o);
			o.worldPos =mul(unity_ObjectToWorld, v.vertex).xyz;
			o.position = mul(UNITY_MATRIX_MVP, v.vertex);

            float offset = frac( _Time.x *_OffsetSpeed);
            half2 tiling = o.worldPos.xz * _Tiling;
            o.tilings.xy = tiling + offset;
            o.tilings.zw = half2(-tiling.y, tiling.x) - offset;
		}
		
		void surf (Input IN, inout SurfaceOutput o)
		{
			float3 worldView = (IN.worldPos - _WorldSpaceCameraPos);
			
            half4 nmap = tex2D(_WaterTex, IN.tilings.xy) + tex2D(_WaterTex, IN.tilings.zw);
            o.Normal = nmap.xyz - 1.0;

			// World space normal (Y-up)
			half3 worldNormal = o.Normal.xzy;
			worldNormal.z = -worldNormal.z;
		    
            float3 mainC =tex2D(_MainTex,IN.uv_MainTex).rgb;
            float depth =mainC.g;

// Calculate the depth ranges (X = Alpha, Y = Color Depth)
            half3 ranges = _InvRanges.xyz * depth;
            ranges.y = saturate(1.0 - ranges.y);

            half4 col ;
            col.rgb = lerp(_Color1.rgb, _Color.rgb, ranges.y);
            col.a = saturate(ranges.z +ranges.x);

            // Initial material properties
            o.Alpha = col.a*0.7;
            o.Specular = col.a;
            o.Gloss = _Shininess;

            half fresnel =saturate( dot(-normalize(worldView), worldNormal));
            fresnel = 1-fresnel;

            half3 reflection = texCUBE(_Cube, reflect(worldView, worldNormal)).rgb * _ReflectionTint;

            half3  refraction = lerp(_Color.rgb, _Color1.rgb,mainC.r);
            refraction *=col.rgb ; 

            fresnel *= fresnel;
            fresnel = (0.8 * fresnel + 0.2) * col.a;

            o.Albedo = lerp(refraction, reflection, fresnel *0.8);
            // Calculate the amount of illumination that the pixel has received already
            o.Emission = o.Albedo * (1.0 - fresnel);
		    
        #ifdef USING_DIRECTIONAL_LIGHT
            o.Albedo *= fresnel;
        #else
            // Setting it directly using the equals operator causes the shader to be "optimized" and break
            o.Albedo = lerp(o.Albedo.r, 1.0, 1.0);
        #endif
        
		}
		ENDCG
	}
    
	FallBack "Legacy Shaders/Transparent/VertexLit"
}
