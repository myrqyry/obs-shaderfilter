uniform float radius<
    string label = "Radius";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 2.0;
    float step = 0.01;
> = 0.8;
uniform float softness<
    string label = "Softness";
    string widget_type = "slider";
    float minimum = 0.01;
    float maximum = 1.0;
    float step = 0.01;
> = 0.4;
uniform float4 vignetteColor<
    string label = "Vignette Color";
> = { 0.0, 0.0, 0.0, 1.0 };
uniform float pulseSpeed<
    string label = "Pulse Speed";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 10.0;
    float step = 0.1;
> = 2.0;
uniform float pulseAmount<
    string label = "Pulse Amount";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.01;
> = 0.15;

float4 mainImage(VertData v_in) : TARGET
{
	float4 original = image.Sample(textureSampler, v_in.uv);

	float2 centered = v_in.uv - 0.5;
	float dist = length(centered) * 1.414;

	float pulse = 1.0 + sin(elapsed_time * pulseSpeed) * pulseAmount;
	float effectiveRadius = radius * pulse;

	float vignette = smoothstep(effectiveRadius, effectiveRadius - softness, dist);

	float4 result = lerp(vignetteColor, original, vignette);
	result.a = original.a;
	return result;
}

technique Draw
{
	pass
	{
		vertex_shader = mainTransform(v_in);
		pixel_shader  = mainImage(v_in);
	}
}
