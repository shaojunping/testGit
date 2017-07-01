Shader "TianShen/Particle Title AlphaBlend_gai" {
    Properties {
        _TintColor ("TintColor", Color) = (0.5,0.5,0.5,1)
        _MainTex ("Main Texture", 2D) = "white" {}
        _ScrollX ("Base layer Scroll speed X", Float) = 1.0
	    _ScrollY ("Base layer Scroll speed Y", Float) = 0.0
        _Alpha ("Mask", 2D) = "black" {}        
        _Cutout ("Cutout", Float ) = 1        
    }
    SubShader {
        Tags {
            "IgnoreProjector"="True"
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }
        Pass {
            Name "ForwardBase"
            Tags {
                "LightMode"="ForwardBase"
            }
            //Blend SrcAlpha One
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            //ZTest NotEqual
            Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            uniform sampler2D _Alpha; uniform float4 _Alpha_ST;
            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            float _ScrollX;
		    float _ScrollY;
            uniform float4 _TintColor;
            uniform float _Cutout;
            struct VertexInput {
                float4 vertex : POSITION;
                float4 uv0 : TEXCOORD0;
                fixed4 color : COLOR;
            };
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float2 uvRe :TEXCOORD1;
                fixed4 color : COLOR;
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o;
                o.uv0 = TRANSFORM_TEX(v.uv0.rg, _Alpha);
                o.uvRe =TRANSFORM_TEX(v.uv0.xy,_MainTex)  + frac(float2(_ScrollX, _ScrollY) * _Time);
                o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				
				o.color = v.color;
                
                return o;
            }
            fixed4 frag(VertexOutput i) : COLOR {

                float4 MainCol = tex2D(_MainTex,i.uvRe.xy);
                //float3 emissive = saturate(( MainCol.rgb > 0.5 ? (1.0-(1.0-2.0*(MainCol.rgb-0.5))*(1.0-_TintColor.rgb)) : (2.0*MainCol.rgb*_TintColor.rgb) ))*MainCol.a;
                //float3 finalColor = emissive;
                fixed4 tempAlpha =tex2D(_Alpha,i.uv0.xy);
                MainCol.a = MainCol.a  *tempAlpha.r;
                return MainCol;
                //return fixed4(finalColor,tex2D(_Alpha,i.uv0.xy).r*_Cutout)*i.color;
            }
            ENDCG
        }
    }
    FallBack "Mobile/VertexLit"
}