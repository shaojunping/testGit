// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "TSHD/AlphaTest_Unlit_WindSustain" {
    Properties {
         _EmissionColor ("EmissionColor", Color) = (0.0,0.0,0.0,1.0) 
        _MainTex ("Diffuse(RGBA)", 2D) = "white" {}
        //_AlphaTex ("AlphaTex(R)", 2D) = "white" {}
        _Wind("Wind params（XZ for Direction,W for Weight Scale)",Vector) = (1,1,1,1)
        [HideInInspector]_ColliderForce ("Collider Force(Control by Script)", float) = 0.0
        _WindEdgeFlutterFreqScale("Wind Freq Scale",float) = 0.5
        _Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Float) = 2

         [HideInInspector]_PlayerForce("XYZ for PlayerPos,W for PlayerForce Weight",Vector) =(0,0,0,0)
        _DirForce("XYZ for Wind Direction,W for PlayerForce Weight",Vector) =(0,0,0,0)
        _ForceWeight("Force Weight",float)=0.0 //All force weight
    }
    SubShader {
        Tags {
            "Queue"="AlphaTest"
            "RenderType"="TransparentCutout"
        }
        Pass {
            Name "ForwardBase"
            Tags {
                "LightMode"="ForwardBase"
            }
            Cull [_Cull]

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            //#define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            //#include "AutoLight.cginc"
            #include "Lighting.cginc"
            //#pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile LIGHTMAP_ON LIGHTMAP_OFF

            uniform sampler2D _MainTex; uniform float4 _MainTex_ST;
            //uniform sampler2D _AlphaTex;
            float4 _Wind,_PlayerForce,_DirForce;
            fixed _Cutoff,_AmbScale;
            float _WindEdgeFlutterFreqScale,_ForceWeight;
            fixed3 _EmissionColor;
            float _ColliderForce;
			float4 _GlobalTreeForce;
			float _GlobalTreeWindEdgeFlutterFreqScale;
			//float
            struct VertexInput {
                float4 vertex : POSITION;

                float2 texcoord0 : TEXCOORD0;
                float2 texcoord1 : TEXCOORD1;
                float4 vertexColor : COLOR;
            };
            struct VertexOutput {
                float4 pos : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                half4 posWorld : TEXCOORD1;
                UNITY_FOG_COORDS(3)
                #ifndef LIGHTMAP_OFF
                    float2 uvLM : TEXCOORD2;
                #endif
            };
            VertexOutput vert (VertexInput v) {
                VertexOutput o;
                o.uv0 =  TRANSFORM_TEX(v.texcoord0, _MainTex);

                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                half 	 windTime 	= _Time.y *(_WindEdgeFlutterFreqScale+_GlobalTreeWindEdgeFlutterFreqScale)*10;
                
                half3 pForce = normalize(o.posWorld -_PlayerForce.xyz) *_PlayerForce.w*2;     
                half3 wForce =_DirForce.xyz*_DirForce.w;

                o.posWorld.x += cos(windTime+_Wind.x+_GlobalTreeForce.x) *sin(o.posWorld.z+windTime)* (_Wind.w +_ColliderForce+_GlobalTreeForce.w) * v.vertexColor.a *0.1;
                o.posWorld.z += sin(windTime+_Wind.z+_GlobalTreeForce.z)*cos(o.posWorld.z+windTime)  * (_Wind.w +_ColliderForce+_GlobalTreeForce.w)* v.vertexColor.a*0.1;          

                o.posWorld.xz +=(pForce.xz+wForce.xz)*v.vertexColor.a*_ForceWeight;    

				v.vertex = mul(unity_WorldToObject, o.posWorld);

                o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
                UNITY_TRANSFER_FOG(o,o.pos);
                #ifndef LIGHTMAP_OFF
                    o.uvLM = v.texcoord1 * unity_LightmapST.xy + unity_LightmapST.zw;
                #endif

                return o;
            }

            fixed4 frag(VertexOutput i) : COLOR {
                float4 diffuse = tex2D(_MainTex,TRANSFORM_TEX(i.uv0, _MainTex));
                //fixed4 b = tex2D(_AlphaTex,i.uv0) ;
				clip(diffuse.a -_Cutoff);
                
                fixed4 finalColor =fixed4(1.0,1.0,1.0,1.0);
                finalColor.rgb= diffuse.rgb+diffuse.rgb *_EmissionColor;

                #ifndef LIGHTMAP_OFF
                    float4 lmtex = UNITY_SAMPLE_TEX2D(unity_Lightmap,i.uvLM);
                    float3 lightmap = DecodeLightmap(lmtex);
                    finalColor.rgb *=lightmap;
                #endif

                finalColor.rgb = lerp(finalColor.rgb,finalColor.rgb *UNITY_LIGHTMODEL_AMBIENT,_AmbScale); //mul Amb
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                return finalColor;
            }
            ENDCG
        }
    }
    Fallback "Legacy Shaders/Transparent/Cutout/VertexLit"
   //Fallback "TSHD/AlphaTest_VertexLit"
}
