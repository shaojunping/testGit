///Upadte 11.18,Remove Occ & Emission,MainTex insteand of  EmissionMap
///Update 9.23
Shader "TSHD/PBS_SSS" {
	Properties {
		_Color("Color", Color) = (1,1,1,1)
		_MainTex("Albedo", 2D) = "white" {}
		_Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5

		_Glossiness("Smoothness", Range(0.0, 1.0)) = 1.0
		_SpecColor("SpecularColor", Color) = (0.2,0.2,0.2)
		_SpecGlossMap("Specular", 2D) = "white" {}
        //_SmoothMap("Smooth", 2D) = "grey" {}
        _BRDFTex ("Brdf Map(R for BRDF,G for Mask,B for Thickness)", 2D) = "white" {}

		_BumpScale("Scale", Float) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0
		_OcclusionMap("Occlusion", 2D) = "white" {}
		
		_EmissionColor("EmissionColor", Color) = (0,0,0)
        //_EmissionMap("Emission", 2D) = "white" {}
		//RIM LIGHT
		_RimColor ("Rim Color", Color) = (0.8,0.8,0.8,0.6)
		_RimPower ("Rim Power", Range(0,5)) = 3.0
		_RimLevel ("Rim Level",Range(0,3)) = 0.5
        _RimDir("Rim Direction(W>0 Direction Rim,or esle Full Rim)",Vector) =(1,1,0,1)
        //_Thickness = Thickness texture (invert normals, bake AO).
		//_Power = "Sharpness" of translucent glow.
		//_Distortion = Subsurface distortion, shifts surface normal, effectively a refractive index.
		//_Scale = Multiplier for translucent glow - should be per-light, really.
		//_SubColor = Subsurface colour.
		_SubPower ("Subsurface Power", Range(1,20)) = 1.0
		_SubDistortion ("Subsurface Distortion", Range(-1,1)) = 0.0
		_SubScale ("Subsurface Scale", Range(0,10)) = 1.0
		_SubColor ("Subsurface Color", Color) = (1.0, 1.0, 1.0, 1.0)

		// Blending state
		[HideInInspector] _Mode ("__mode", Float) = 0.0
		[HideInInspector] _SrcBlend ("__src", Float) = 1.0
		[HideInInspector] _DstBlend ("__dst", Float) = 0.0
		[HideInInspector] _ZWrite ("__zw", Float) = 1.0

		[HideInInspector] _SmoothnessTweaks ("__smoothnesstweaks", Vector) = (1,0,0,0)
		_SmoothnessTweak1("Specular Scale Value", Range(0.0, 2.0)) = 1.0 
		_SmoothnessTweak2("Specular Semi Matte", Range(-0.5, 0.5)) = 0.0 
		_SpecularMapColorTweak("Specular Color Tweak", Color) = (1,1,1,1)
	}
	
	SubShader {
		Tags { "RenderType"="Opaque" "IgnoreProjector"="true" }
		LOD 300
		
		Blend [_SrcBlend] [_DstBlend]
		ZWrite [_ZWrite]
		CGPROGRAM

		#pragma surface SurfSpecular StandardSpecularSSS fullforwardshadows keepalpha interpolateview vertex:StandardSurfaceVertex finalcolor:StandardSurfaceSpecularFinal nolightmap nometa exclude_path:deferred exclude_path:prepass noforwardadd 
		#pragma target 3.0

		// Standard shader feature variants
        //#pragma shader_feature _NORMALMAP
		#pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
        
        #pragma multi_compile _NORMALMAP_OFF _NORMALMAP
        #pragma multi_compile _SPECGLOSSMAP_OFF _SPECGLOSSMAP
        //#pragma multi_compile _EMISSION_OFF _EMISSION
        #pragma multi_compile _RIM_OFF _RIM 
        #pragma multi_compile _BRDF_OFF _BRDF
        //The most importan vartiants for other lighting : DIRLIGHTMAP_OFF DYNAMICLIGHTMAP_OFF
        #pragma skip_variants   SHADOWS_SOFT DIRLIGHTMAP_COMBINED DIRLIGHTMAP_SEPARATE FOG_EXP FOG_EXP2 SHADOWS_SCREEN 
		#pragma multi_compile_fog

		uniform half3 		_SpecularMapColorTweak;
		uniform half2		_SmoothnessTweaks;
        //uniform sampler2D        _SmoothMap;
        uniform sampler2D _BRDFTex;

		uniform float _RimPower,_SubPower;
		uniform fixed4 _RimColor,_SubColor;
		uniform fixed _RimLevel,_SubDistortion,_SubScale;
        uniform  float4  _RimDir;
        #include "UnityStandardInput.cginc"
         //-------------------------------------------------------------------------------------
        // Default BRDF to use:
        #if !defined (UNITY_BRDF_PBS) // allow to explicitly override BRDF in custom shader
	        #if (SHADER_TARGET < 30) || defined(SHADER_API_PSP2)
		        // Fallback to low fidelity one for pre-SM3.0
		        #define UNITY_BRDF_PBS BRDF3_Unity_PBS
	        #elif defined(SHADER_API_MOBILE)
		        // Somewhat simplified for mobile
		        #define UNITY_BRDF_PBS BRDF2_Unity_PBS
	        #else
		        // Full quality for SM3+ PC / consoles
		        #define UNITY_BRDF_PBS BRDF1_Unity_PBS
	        #endif
        #endif
     
        struct SurfaceOutputStandardSpecular2
	    {
		    half3	Albedo;		// diffuse color
		    half3	Specular;	// specular color
		    half3	Normal;		// tangent space normal, if written
		    half3	Emission;
		    half	Smoothness;	// 0=rough, 1=smooth
            half	Occlusion;	// occlusion (default 1)
		    half	Alpha;		// alpha for transparencies
		    half	Thickness; //SSS thickness
            half  SSSMask;	
	    };
        
        half4 LightingStandardSpecularSSS(SurfaceOutputStandardSpecular2 s,half3 viewDir, UnityGI gi)
        {
            s.Normal = normalize(s.Normal);
	        // energy conservation 
	        half oneMinusReflectivity;
	        s.Albedo = EnergyConservationBetweenDiffuseAndSpecular (s.Albedo, s.Specular, /*out*/ oneMinusReflectivity);
	        // shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
	        // this is necessary to handle transparency in physically correct way - only diffuse component gets affected by alpha
	        half outputAlpha;
	        s.Albedo = PreMultiplyAlpha (s.Albedo, s.Alpha, oneMinusReflectivity, /*out*/ outputAlpha);
	        half4 c = UNITY_BRDF_PBS (s.Albedo, s.Specular, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, gi.light, gi.indirect);
	        c.rgb += UNITY_BRDF_GI (s.Albedo, s.Specular, oneMinusReflectivity, s.Smoothness, s.Normal, viewDir, s.Occlusion, gi);
	        c.a = outputAlpha;
#ifdef _BRDF
            ///SSS 
            ///From GDC 2011:approximating-translucency-for-a-fast-cheap-and-convincing-subsurfacescattering
            ///we dont want to resive shadow so far
            half3 vLTLight = _WorldSpaceLightPos0.xyz+s.Normal *_SubDistortion;
            half fLTdot =pow(saturate(dot(viewDir,-vLTLight)),_SubPower)*_SubScale;
            //half attenuation = LIGHT_ATTENUATION(i);
            //half3 attenColor = attenuation * _LightColor0.xyz;
            //half fLT = attenColor *2 *fLTdot *s.Thickness*_SubColor.rgb;
            half3 fLT = 2*(fLTdot +s.Emission) *s.Thickness*_SubColor.rgb;
            half3 SSSpart =c.rgb +c.rgb*_LightColor0.rgb*fLT;
//mask for SSS
            c.rgb =lerp(c.rgb,SSSpart,s.SSSMask);
#endif
	        return c;
        }
        
        void LightingStandardSpecularSSS_GI (
	        SurfaceOutputStandardSpecular2 s,
	        UnityGIInput data,
	        inout UnityGI gi)
        {
	        gi = UnityGlobalIllumination (data, s.Occlusion, s.Smoothness, s.Normal);
        }

///
	    struct Input
	    {
		    float4	texcoord;
	    //#ifdef _PARALLAXMAP
		    half3	viewDir;
            half NDL;
            half3 worldNor;
	        //#endif
        #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	        float fogCoord;
        #endif
	    };

		void SurfSpecular(Input IN, inout SurfaceOutputStandardSpecular2 o)
		{
           //#ifdef _PARALLAXMAP
           //     IN.texcoord = Parallax(IN.texcoord, IN.viewDir);
           // #endif
	
           //     o.Alpha = Alpha(IN.texcoord.xy);
           // #if defined(_ALPHATEST_ON)
           //     clip(o.Alpha - _Cutoff);
           // #endif
            //o.Albedo = Albedo(IN.texcoord.xyzw);	
            half3 albedo =tex2D (_MainTex,IN.texcoord.xy).rgb;         
            o.Albedo = albedo *_Color.rgb;	

            #ifdef _BRDF	
                half4 brdfAll =tex2D(_BRDFTex,IN.texcoord.xy);
                o.Thickness =brdfAll.b;
                o.SSSMask =brdfAll.g;

                float2 brdfUV =float2(IN.NDL,0);
                half4 brdf  = tex2D( _BRDFTex, brdfUV );
                //SSS part :Albedo turn to Albedo * SubColor
                half3 SSSpart1 =o.Albedo*(brdf.r +(1-brdf.r) *_SubColor.rgb);
                //mask for SSS
                half3 tempRGB =lerp(o.Albedo,SSSpart1,o.SSSMask);
                o.Albedo =lerp(o.Albedo,tempRGB,_SubColor.a);
            #endif
               
            #ifdef _NORMALMAP
	            o.Normal = NormalInTangentSpace(IN.texcoord.xyzw);
            #endif

	            half4 specGloss = SpecularGloss(IN.texcoord.xy);
	            o.Specular = specGloss.rgb;
	            o.Smoothness = specGloss.a;
                //o.Occlusion = Occlusion(IN.texcoord.xy);

            //#ifdef _EMISSION
                //o.Emission = Emission(IN.texcoord.xy);
                o.Emission =albedo*_EmissionColor.rgb;
            //#else
            //    o.Emission =_EmissionColor.rgb;
            //#endif    

            #ifdef _SPECGLOSSMAP
			o.Specular *= _SpecularMapColorTweak;
            #endif
            #ifdef _RIM
            //half rim = 1.0f -saturate(dot(normalize(IN.viewDir),o.Normal));
            half rim = 1.0f -saturate(dot(IN.viewDir,o.Normal));
			half rimMask =_RimDir.w>0 ? saturate(dot(IN.worldNor, _RimDir.xyz)) : 1;    
            o.Emission += (_RimColor.rgb *pow(rim,_RimPower)) *_RimLevel*rimMask;
            //o.Emission += (_RimColor.rgb *pow(rim,_RimPower)) *_RimLevel;
            #endif
			o.Smoothness = saturate(o.Smoothness * _SmoothnessTweaks.x + _SmoothnessTweaks.y);
		}

        void StandardSurfaceVertex (inout appdata_full v, out Input o)
        {
	        UNITY_INITIALIZE_OUTPUT(Input, o);
            o.worldNor = normalize(UnityObjectToWorldNormal(v.normal));
	        fixed3 lightDir = _WorldSpaceLightPos0.xyz;
	        o.NDL =dot(o.worldNor , lightDir)*0.5 +0.5;
	        o.NDL  = max(0,o.NDL);
        #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	        float4 hpos = mul(UNITY_MATRIX_MVP,v.vertex);
	        UNITY_CALC_FOG_FACTOR(hpos.z);
	        o.fogCoord = unityFogFactor;
        #endif
	        // Setup UVs to the format expected by Standard input functions.
	        o.texcoord.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
	        //o.texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.texcoord : v.texcoord1), _DetailAlbedoMap);
        }

        inline void StandardSurfaceSpecularFinal (Input IN, SurfaceOutputStandardSpecular2 o, inout half4 color)
        {	
        #if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
	        color.a = o.Alpha;
        #else
	        UNITY_OPAQUE_ALPHA(color.a);
        #endif
        #if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
        color.rgb = lerp(unity_FogColor.rgb,color.rgb,saturate(IN.fogCoord));
        #endif
        }

		ENDCG
	}

    CustomEditor "PBSSSSGUI"
    FallBack "Mobile/VertexLit"

}
