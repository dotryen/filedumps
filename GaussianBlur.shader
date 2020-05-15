Shader "Universal Render Pipeline/Custom/Frosted Glass"
{
	Properties
	{
		_BlurSize("Blur Size", Range(0,0.5)) = 0
		[KeywordEnum(Low, Medium, High)] _Samples("Sample amount", Float) = 0
		[Toggle(GAUSS)] _Gauss("Gaussian Blur", float) = 0
		[PowerSlider(3)]_StandardDeviation("Standard Deviation (Gauss only)", Range(0.00, 0.3)) = 0.02
	}

		SubShader
		{
			Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalRenderPipeline" "IgnoreProjector" = "True"}
			LOD 300

			Pass
			{
				// "Lightmode" tag must be "UniversalForward" or not be defined in order for
				// to render objects.
				Name "GaussianBlur"
				Tags{"LightMode" = "UniversalForward"}
				
				Cull Back
				ZWrite Off
				ZTest LEqual

				HLSLPROGRAM
				// Required to compile gles 2.0 with standard SRP library
				// All shaders must be compiled with HLSLcc and currently only gles is not using HLSLcc by default
				#pragma prefer_hlslcc gles
				#pragma exclude_renderers d3d11_9x
				#pragma target 2.0

				// Includes
				#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
				// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
				// #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

				#pragma multi_compile_fog
				#pragma multi_compile_instancing

				#pragma vertex LitPassVertex
				#pragma fragment LitPassFragment

				#pragma multi_compile _SAMPLES_LOW _SAMPLES_MEDIUM _SAMPLES_HIGH
				#pragma shader_feature GAUSS

				#define REQUIRE_OPAQUE_TEXTURE

				float _BlurSize;
				float _StandardDeviation;

				#define PI 3.14159265359
				#define E 2.71828182846

				#if _SAMPLES_LOW
					#define SAMPLES 10
				#elif _SAMPLES_MEDIUM
					#define SAMPLES 30
				#else
					#define SAMPLES 100
				#endif

				struct Attributes
				{
					float4 vertex : POSITION;
				};

				struct Varyings
				{
				    float4 position : SV_POSITION;
					float2 screenPos : TEXCOORD0;
				};

				TEXTURE2D_X(_CameraOpaqueTexture);
				SAMPLER(sampler_CameraOpaqueTexture);

				float4 SampleSceneColor(float2 uv)
				{
					return SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, UnityStereoTransformScreenSpaceTex(uv));
				}

				Varyings LitPassVertex(Attributes i)
				{
					Varyings o;

					VertexPositionInputs vertexInput = GetVertexPositionInputs(i.vertex.xyz);
					o.position = vertexInput.positionCS;
					
					float4 screenPos = ComputeScreenPos(vertexInput.positionCS);
					o.screenPos = screenPos.xy / screenPos.w;

					return o;
				}

				half4 LitPassFragment(Varyings i) : SV_Target
				{

				#if GAUSS
					//failsafe so we can use turn off the blur by setting the deviation to 0
					if (_StandardDeviation == 0)
					return SampleSceneColor(i.screenPos);
				#endif

				// Vertical Blur
				//init color variable
				float4 vCol = 0;
				#if GAUSS
					float vSum = 0;
				#else
					float vSum = SAMPLES;
				#endif
				//iterate over blur samples
				for (float vIndex = 0; vIndex < SAMPLES; vIndex++) {
					//get the offset of the sample
					float offset = (vIndex / (SAMPLES - 1) - 0.5) * _BlurSize;
					//get screenPos coordinate of sample
					float2 screenPos = i.screenPos + float2(0, offset);
				#if !GAUSS
					//simply add the color if we don't have a gaussian blur (box)
					vCol += SampleSceneColor(screenPos);
				#else
					//calculate the result of the gaussian function
					float stDevSquared = _StandardDeviation * _StandardDeviation;
					float gauss = (1 / sqrt(2 * PI * stDevSquared)) * pow(E, -((offset * offset) / (2 * stDevSquared)));
					//add result to sum
					vSum += gauss;
					//multiply color with influence from gaussian function and add it to sum color
					vCol += SampleSceneColor(screenPos) * gauss;
				#endif
				}
				//divide the sum of values by the amount of samples
				vCol = vCol / vSum;

				//Horizontal Blur
				//calculate aspect ratio
				float invAspect = _ScreenParams.y / _ScreenParams.x;
				//init color variable
				float4 hCol = 0;
				#if GAUSS
					float hSum = 0;
				#else
					float hSum = SAMPLES;
				#endif
				//iterate over blur samples
				for (float hIndex = 0; hIndex < SAMPLES; hIndex++) {
					//get the offset of the sample
					float offset = (hIndex / (SAMPLES - 1) - 0.5) * _BlurSize * invAspect;
					//get screenPos coordinate of sample
					float2 screenPos = i.screenPos + float2(offset, 0);
					#if !GAUSS
						//simply add the color if we don't have a gaussian blur (box)
						hCol += SampleSceneColor(screenPos);
					#else
						//calculate the result of the gaussian function
						float stDevSquared = _StandardDeviation * _StandardDeviation;
						float gauss = (1 / sqrt(2 * PI * stDevSquared)) * pow(E, -((offset * offset) / (2 * stDevSquared)));
						//add result to sum
						hSum += gauss;
						//multiply color with influence from gaussian function and add it to sum color
						hCol += SampleSceneColor(screenPos) * gauss;
					#endif
				}
				//divide the sum of values by the amount of samples
				hCol = hCol / hSum;

				float4 combinedCol = hCol + vCol;
				return combinedCol / 2;
				}
				ENDHLSL
			}

		// Used for depth prepass
		// If shadows cascade are enabled we need to perform a depth prepass. 
		// We also need to use a depth prepass in some cases camera require depth texture
		// (e.g, MSAA is enabled and we can't resolve with Texture2DMS
		UsePass "Universal Render Pipeline/Lit/DepthOnly"

		// Used for Baking GI. This pass is stripped from build.
		UsePass "Universal Render Pipeline/Lit/Meta"
    }
}