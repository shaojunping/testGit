Shader "Hidden/Image Effects/UEBloom"
{
    Properties
    {
        _MainTex("", 2D) = "" {}
        _BaseTex("", 2D) = "" {}
    }
	CGINCLUDE
        #include "UnityCG.cginc"

        // Mobile: use RGBM instead of float/half RGB
        #define USE_RGBM defined(SHADER_API_MOBILE)

        sampler2D _MainTex;
        sampler2D _BaseTex;
        sampler2D _PreTex;
        float2 _MainTex_TexelSize;
        float2 _BaseTex_TexelSize;
        float2 _PreTex_TexelSize;
        half4 _MainTex_ST;
        half4 _BaseTex_ST;
        half4 __PrTex_ST;

        float _PrefilterOffs;
        half _Threshold;
        half3 _Curve;
        float _SampleScale;
        half _Intensity;
        half2 _Offset;

        sampler2D _TapLowBackground;	
        // Brightness function
        half Brightness(half3 c)
        {
            return max(max(c.r, c.g), c.b);
        }

        // 3-tap median filter
        half3 Median(half3 a, half3 b, half3 c)
        {
            return a + b + c - min(min(a, b), c) - max(max(a, b), c);
        }

        // Clamp HDR value within a safe range
        half3 SafeHDR(half3 c) { return min(c, 65000); }
        half4 SafeHDR(half4 c) { return min(c, 65000); }

        // RGBM encoding/decoding
        half4 EncodeHDR(float3 rgb)
        {
        //#if USE_RGBM
        //    rgb *= 1.0 / 8;
        //    float m = max(max(rgb.r, rgb.g), max(rgb.b, 1e-6));
        //    m = ceil(m * 255) / 255;
        //    return half4(rgb / m, m);
        //#else
            return half4(rgb, 0);
        //#endif
        }

        float3 DecodeHDR(half4 rgba)
        {
        //#if USE_RGBM
        //    return rgba.rgb * rgba.a * 8;
        //#else
            return rgba.rgb;
        //#endif
        }

        // Downsample with a 4x4 box filter
        half3 DownsampleFilter(float2 uv)
        {
            float4 d = _MainTex_TexelSize.xyxy * float4(-1, -1, +1, +1);

            half3 s;
            s  = DecodeHDR(tex2D(_MainTex, uv + d.xy));
            s += DecodeHDR(tex2D(_MainTex, uv + d.zy));
            s += DecodeHDR(tex2D(_MainTex, uv + d.xw));
            s += DecodeHDR(tex2D(_MainTex, uv + d.zw));

            return s * (1.0 / 4);
        }

        // Downsample with a 4x4 box filter + anti-flicker filter
        half3 DownsampleAntiFlickerFilter(float2 uv)
        {
            float4 d = _MainTex_TexelSize.xyxy * float4(-1, -1, +1, +1);

            half3 s1 = DecodeHDR(tex2D(_MainTex, uv + d.xy));
            half3 s2 = DecodeHDR(tex2D(_MainTex, uv + d.zy));
            half3 s3 = DecodeHDR(tex2D(_MainTex, uv + d.xw));
            half3 s4 = DecodeHDR(tex2D(_MainTex, uv + d.zw));

            // Karis's luma weighted average (using brightness instead of luma)
            half s1w = 1 / (Brightness(s1) + 1);
            half s2w = 1 / (Brightness(s2) + 1);
            half s3w = 1 / (Brightness(s3) + 1);
            half s4w = 1 / (Brightness(s4) + 1);
            half one_div_wsum = 1 / (s1w + s2w + s3w + s4w);

            return (s1 * s1w + s2 * s2w + s3 * s3w + s4 * s4w) * one_div_wsum;
        }

        half3 UpsampleFilter(float2 uv)
        {
        #if HIGH_QUALITY
            // 9-tap bilinear upsampler (tent filter)
            float4 d = _MainTex_TexelSize.xyxy * float4(1, 1, -1, 0) * _SampleScale;

            half3 s;
            s  = DecodeHDR(tex2D(_MainTex, uv - d.xy));
            s += DecodeHDR(tex2D(_MainTex, uv - d.wy)) * 2;
            s += DecodeHDR(tex2D(_MainTex, uv - d.zy));

            s += DecodeHDR(tex2D(_MainTex, uv + d.zw)) * 2;
            s += DecodeHDR(tex2D(_MainTex, uv       )) * 4;
            s += DecodeHDR(tex2D(_MainTex, uv + d.xw)) * 2;

            s += DecodeHDR(tex2D(_MainTex, uv + d.zy));
            s += DecodeHDR(tex2D(_MainTex, uv + d.wy)) * 2;
            s += DecodeHDR(tex2D(_MainTex, uv + d.xy));

            return s * (1.0 / 16);
        #else
            // 4-tap bilinear upsampler
            float4 d = _MainTex_TexelSize.xyxy * float4(-1, -1, +1, +1) * (_SampleScale * 0.5);

            half3 s;
            s  = DecodeHDR(tex2D(_MainTex, uv + d.xy));
            s += DecodeHDR(tex2D(_MainTex, uv + d.zy));
            s += DecodeHDR(tex2D(_MainTex, uv + d.xw));
            s += DecodeHDR(tex2D(_MainTex, uv + d.zw));

            return s * (1.0 / 4);
        #endif
        }

        half3 UpsamplePreFilter(float2 uv)
        {
        #if HIGH_QUALITY
            // 9-tap bilinear upsampler (tent filter)
            float4 d = _PreTex_TexelSize.xyxy * float4(1, 1, -1, 0) * _SampleScale;

            half3 s;
            s  = DecodeHDR(tex2D(_PreTex, uv - d.xy));
            s += DecodeHDR(tex2D(_PreTex, uv - d.wy)) * 2;
            s += DecodeHDR(tex2D(_PreTex, uv - d.zy));

            s += DecodeHDR(tex2D(_PreTex, uv + d.zw)) * 2;
            s += DecodeHDR(tex2D(_PreTex, uv       )) * 4;
            s += DecodeHDR(tex2D(_PreTex, uv + d.xw)) * 2;

            s += DecodeHDR(tex2D(_PreTex, uv + d.zy));
            s += DecodeHDR(tex2D(_PreTex, uv + d.wy)) * 2;
            s += DecodeHDR(tex2D(_PreTex, uv + d.xy));

            return s * (1.0 / 16);
        #else
            // 4-tap bilinear upsampler
            float4 d = _PreTex_TexelSize.xyxy * float4(-1, -1, +1, +1) * (_SampleScale * 0.5);

            half3 s;
            s  = DecodeHDR(tex2D(_PreTex, uv + d.xy));
            s += DecodeHDR(tex2D(_PreTex, uv + d.zy));
            s += DecodeHDR(tex2D(_PreTex, uv + d.xw));
            s += DecodeHDR(tex2D(_PreTex, uv + d.zw));

            return s * (1.0 / 4);
        #endif
        }

        //
        // Vertex shader
        //

        v2f_img vert(appdata_img v)
        {
            v2f_img o;
        #if UNITY_VERSION >= 540
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uv = UnityStereoScreenSpaceUVAdjust(v.texcoord, _MainTex_ST);
        #else
            o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
            o.uv = v.texcoord;
        #endif
            return o;
        }

        struct v2f_b{
		        half4 pos : SV_POSITION;
		        half4  uv [5] : TEXCOORD0;
	        };

	        struct v2f_opts{
		        half4 pos : SV_POSITION;
		        half2 uv [7] : TEXCOORD0;
	        };

        struct v2f_multitex
        {
            float4 pos : SV_POSITION;
            float2 uvMain : TEXCOORD0;
            float2 uvBase : TEXCOORD1;
        };

        v2f_b vertWithMultiCoords2(appdata_img v){
		        v2f_b o;
		        o.pos=mul(UNITY_MATRIX_MVP,v.vertex);
		        o.uv[0].xy = v.texcoord.xy;
		
		        o.uv[0].zw=v.texcoord.xy;
		
		        o.uv[1] = v.texcoord.xyxy +  _Offset.xyxy*half4(1,1,-1,-1);
		        o.uv[2] = v.texcoord.xyxy - _Offset.xyxy*half4(1,1,-1,-1)*2.0;	
		        o.uv[3] = v.texcoord.xyxy - _Offset.xyxy*half4(1,1,-1,-1)*3.0;	
		        o.uv[4] = v.texcoord.xyxy + _Offset.xyxy*half4(1,1,-1,-1)*4.0;	
		        return o;
	        }

	        v2f_opts vertStretch (appdata_img v) {
                v2f_opts o;
                o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
                //half b = stretchWidth;  
		    
                o.uv[0] = v.texcoord.xy;
                o.uv[1] = v.texcoord.xy + 2.0 * _Offset.xy;  //offsets�û�����Ȩֵ
                o.uv[2] = v.texcoord.xy -  2.0 * _Offset.xy;
                o.uv[3] = v.texcoord.xy + 4.0 * _Offset.xy;
                o.uv[4]= v.texcoord.xy -  4.0 * _Offset.xy;
                o.uv[5] = v.texcoord.xy +  6.0 * _Offset.xy;
                o.uv[6] = v.texcoord.xy -  6.0 * _Offset.xy;
                return o;
            }

        v2f_multitex vert_multitex(appdata_img v)
        {
            v2f_multitex o;
        #if UNITY_VERSION >= 540
            o.pos = UnityObjectToClipPos(v.vertex);
            o.uvMain = UnityStereoScreenSpaceUVAdjust(v.texcoord, _MainTex_ST);
            o.uvBase = UnityStereoScreenSpaceUVAdjust(v.texcoord, _BaseTex_ST);
        #else
            o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
            o.uvMain = v.texcoord;
            o.uvBase = v.texcoord;
        #endif
        #if UNITY_UV_STARTS_AT_TOP
            if (_BaseTex_TexelSize.y < 0.0)
                o.uvBase.y = 1.0 - v.texcoord.y;
                //o.uvMain  =o.uvBase;
        #endif
            return o;
        }

        //
        // fragment shader
        //
        half4 fragGaussBlur(v2f_b i):SV_Target
	        {
		        half4 color = half4 (0,0,0,0);
		        color += 0.225 * tex2D (_MainTex, i.uv[0].xy);
		        color += 0.150 * tex2D (_MainTex, i.uv[1].xy);
		        color += 0.150 * tex2D (_MainTex, i.uv[1].zw);
		        color += 0.110 * tex2D (_MainTex, i.uv[2].xy);
		        color += 0.110 * tex2D (_MainTex, i.uv[2].zw);
		        color += 0.075 * tex2D (_MainTex, i.uv[3].xy);
		        color += 0.075 * tex2D (_MainTex, i.uv[3].zw);	
		        color += 0.0525 * tex2D (_MainTex, i.uv[4].xy);
		        color += 0.0525 * tex2D (_MainTex, i.uv[4].zw);
		
		        return color;
	        }

        half4 fragStretch (v2f_opts i) : SV_Target 
	        {
                half4 color = tex2D (_MainTex, i.uv[0]);
                color = max (color, tex2D (_MainTex, i.uv[1]));
                color = max (color, tex2D (_MainTex, i.uv[2]));
                color = max (color, tex2D (_MainTex, i.uv[3]));
                color = max (color, tex2D (_MainTex, i.uv[4]));
                color = max (color, tex2D (_MainTex, i.uv[5]));
                color = max (color, tex2D (_MainTex, i.uv[6]));
                return color;
            }   

        half4 frag_prefilter(v2f_img i) : SV_Target
        {
            float2 uv = i.uv + _MainTex_TexelSize.xy * _PrefilterOffs;

        #if ANTI_FLICKER
            float3 d = _MainTex_TexelSize.xyx * float3(1, 1, 0);
            half4 s0 = SafeHDR(tex2D(_MainTex, uv));
            half3 s1 = SafeHDR(tex2D(_MainTex, uv - d.xz).rgb);
            half3 s2 = SafeHDR(tex2D(_MainTex, uv + d.xz).rgb);
            half3 s3 = SafeHDR(tex2D(_MainTex, uv - d.zy).rgb);
            half3 s4 = SafeHDR(tex2D(_MainTex, uv + d.zy).rgb);
            half3 m = Median(Median(s0.rgb, s1, s2), s3, s4);
        #else
            half4 s0 = SafeHDR(tex2D(_MainTex, uv));
            half3 m = s0.rgb;
        #endif

        #if UNITY_COLORSPACE_GAMMA
            m = GammaToLinearSpace(m);
        #endif
            // Pixel brightness
            half br = Brightness(m);

            // Under-threshold part: quadratic curve
            half rq = clamp(br - _Curve.x, 0, _Curve.y);
            rq = _Curve.z * rq * rq;


            // Combine and apply the brightness response curve.
            m *= max(rq, br - _Threshold) / max(br, 1e-5);
	        //m *=saturate(br -_Threshold -0.01);
            return EncodeHDR(m);
        }

        half4 frag_downsample1(v2f_img i) : SV_Target
        {
        #if ANTI_FLICKER
            return EncodeHDR(DownsampleAntiFlickerFilter(i.uv));
        #else
            return EncodeHDR(DownsampleFilter(i.uv));
        #endif
        }

        half4 frag_downsample2(v2f_img i) : SV_Target
        {
            return EncodeHDR(DownsampleFilter(i.uv));
        }

        half4 frag_upsample(v2f_multitex i) : SV_Target
        {
            half3 base = DecodeHDR(tex2D(_BaseTex, i.uvBase));
            half3 blur = UpsampleFilter(i.uvMain);
            return EncodeHDR(base + blur);
        }

        half4 frag_upsample_final(v2f_multitex i) : SV_Target
        {
            half4 base = tex2D(_BaseTex, i.uvBase);
            half3 blur = UpsampleFilter(i.uvMain);
        #if UNITY_COLORSPACE_GAMMA
            base.rgb = GammaToLinearSpace(base.rgb);
        #endif
            half3 cout = base.rgb + blur * _Intensity;
        #if UNITY_COLORSPACE_GAMMA
            cout = LinearToGammaSpace(cout);
        #endif
            return half4(cout, base.a);
        }

        half4 frag_upBloomsample_final(v2f_multitex i) : SV_Target
        {
            half4 tapLow = tex2D (_TapLowBackground, i.uvBase.xy); // already mixed with medium blur
            #if UNITY_UV_STARTS_AT_TOP
                if (_BaseTex_TexelSize.y < 0.0)
                {
                    i.uvBase.y = 1.0 - i.uvBase.y;
                    i.uvMain.y = 1.0 - i.uvMain.y;
                }
            #endif
            half4 base = tex2D(_BaseTex, i.uvBase);

            half3 blur = UpsamplePreFilter(i.uvMain);

	        //computer color in Linearspace,and then back to GammaSpace(to screen)
        #if UNITY_COLORSPACE_GAMMA
            base.rgb = GammaToLinearSpace(base.rgb);
	        tapLow.rgb =GammaToLinearSpace(tapLow.rgb);
        #endif
            half3  cout = base.rgb ;
            cout = lerp (base.rgb, tapLow.rgb, tapLow.a);
            cout +=blur * _Intensity;

            //cout =tapLow.rgb;

        #if UNITY_COLORSPACE_GAMMA
            cout = LinearToGammaSpace(cout);
        #endif

            return half4(cout, base.a);
        }
ENDCG


    SubShader
    {
        // 0: Prefilter
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA
            #pragma vertex vert
            #pragma fragment frag_prefilter
            #pragma target 3.0
            ENDCG
        }
        // 1: Prefilter with anti-flicker
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #define ANTI_FLICKER 1
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA
            #pragma vertex vert
            #pragma fragment frag_prefilter
            #pragma target 3.0
            ENDCG
        }
        // 2: First level downsampler
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag_downsample1
            #pragma target 3.0
            ENDCG
        }
        // 3: First level downsampler with anti-flicker
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #define ANTI_FLICKER 1
            #pragma vertex vert
            #pragma fragment frag_downsample1
            #pragma target 3.0
            ENDCG
        }
        // 4: Second level downsampler
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag_downsample2
            #pragma target 3.0
            ENDCG
        }
        // 5: Upsampler
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #pragma vertex vert_multitex
            #pragma fragment frag_upsample
            #pragma target 3.0
            ENDCG
        }
        // 6: High quality upsampler
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #define HIGH_QUALITY 1
            #pragma vertex vert_multitex
            #pragma fragment frag_upsample
            #pragma target 3.0
            ENDCG
        }
        // 7: Combiner
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA
            #pragma vertex vert_multitex
            #pragma fragment frag_upsample_final
            #pragma target 3.0
            ENDCG
        }
        // 8: High quality combiner
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #define HIGH_QUALITY 1
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA
            #pragma vertex vert_multitex
            #pragma fragment frag_upsample_final
            #pragma target 3.0
            ENDCG
        }

        //9 GasussBlur
		Pass
		{
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
			CGPROGRAM
            //#pragma vertex vertWithMultiCoords2
            //#pragma fragment fragGaussBlur
            #pragma vertex vertStretch
            #pragma fragment fragStretch
			ENDCG
		}
        
        // 10: Combiner BLoom +DOF combine
        Pass
        {
            ZTest Always Cull Off ZWrite Off
            ColorMask RGB
            CGPROGRAM
            #pragma multi_compile _ UNITY_COLORSPACE_GAMMA
            #pragma vertex vert_multitex
            #pragma fragment frag_upBloomsample_final
            #pragma target 3.0
            ENDCG
        }
    }
}
