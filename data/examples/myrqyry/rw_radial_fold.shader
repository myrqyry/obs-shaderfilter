// Radial Direction Fold — OBS Shaderfilter standalone template-mode filter.
// Accident 001 inspired: atan(x,x) gives two direction bands rather than a conventional twirl.
// Source: Jan Kohlbach, real-world-shader (MIT), https://github.com/jankohlbach/real-world-shader ; see REAL-WORLD-SHADER-LICENSE.txt
// Set "Override Entire Effect" OFF; source texture comes from Shaderfilter.
// Source RGB is alpha-divided by Shaderfilter's standard input path;
// pass the original source alpha through without forcing opacity.
uniform float Mix<
    string label = "Effect Mix";
    string group = "Output";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 1.0; float step = 0.01;
> = 1.0;
uniform float Fold_Strength<
    string label = "Fold amount";
    string group = "Shape";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 2.0; float step = 0.01;
> = 1.0;
uniform float Radius<
    string label = "Twist radius";
    string group = "Shape";
    string widget_type = "slider";
    float minimum = 0.1; float maximum = 1.5; float step = 0.01;
> = 0.85;
uniform float Speed<
    string label = "Speed";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 0.0; float maximum = 4.0; float step = 0.05;
> = 1.2;


float4 mainImage(VertData v_in) : TARGET {
    float2 uv = v_in.uv;
    float4 original = image.Sample(textureSampler, uv);
    if (Mix <= 0.0) return original;

    float2 p = uv - 0.5;
    float radius = length(p);
    float fold = atan2(p.x, p.x + 0.000001);
    float twist = Fold_Strength * 3.14159265 * sin(elapsed_time * Speed) *
                  (1.0 - smoothstep(0.0, max(Radius, 0.001), radius));
    float angle = fold + twist;
    float2 sourceUv = 0.5 + float2(cos(angle), sin(angle)) * radius;
    float4 displaced = image.Sample(textureSampler, saturate(sourceUv));
    return lerp(original, float4(displaced.rgb, original.a), Mix);
}
