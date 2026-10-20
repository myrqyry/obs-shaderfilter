// Enter text in an OBS Text source with a transparent background, then select
// that source in Text Mask below. The shader extrudes its alpha silhouette.

uniform string usage<
    string widget_type = "info";
> = "Type/edit text in an OBS Text source, then choose it as Text Mask. Use a transparent background and matching canvas aspect.";

uniform texture2d Text_Mask<
    string label = "Text Mask";
    string widget_type = "source";
>;

uniform float thickness<
    string label = "Extrusion Depth";
    string widget_type = "slider";
    float minimum = 0.02;
    float maximum = 0.80;
    float step = 0.01;
> = 0.18;

uniform float scale<
    string label = "Scale";
    string widget_type = "slider";
    float minimum = 0.25;
    float maximum = 2.00;
    float step = 0.01;
> = 1.0;

uniform float rotation_x<
    string label = "Tilt X";
    string widget_type = "slider";
    float minimum = -70.0;
    float maximum = 70.0;
    float step = 1.0;
> = 18.0;

uniform float rotation_y<
    string label = "Turn Y";
    string widget_type = "slider";
    float minimum = -70.0;
    float maximum = 70.0;
    float step = 1.0;
> = -24.0;

uniform float rotation_z<
    string label = "Roll Z";
    string widget_type = "slider";
    float minimum = -180.0;
    float maximum = 180.0;
    float step = 1.0;
> = 0.0;

uniform float4 face_color = {0.18, 0.72, 1.0, 1.0};
uniform float4 side_color = {0.035, 0.12, 0.24, 1.0};
uniform float threshold<
    string label = "Mask Threshold";
    string widget_type = "slider";
    float minimum = 0.05;
    float maximum = 0.95;
    float step = 0.01;
> = 0.5;

float3 rotate_x(float3 p, float a)
{
    float c = cos(a);
    float s = sin(a);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

float3 rotate_y(float3 p, float a)
{
    float c = cos(a);
    float s = sin(a);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

float3 rotate_z(float3 p, float a)
{
    float c = cos(a);
    float s = sin(a);
    return float3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

float3 rotate_object(float3 p)
{
    return rotate_z(rotate_y(rotate_x(p, radians(rotation_x)), radians(rotation_y)), radians(rotation_z));
}

float3 inverse_rotate_object(float3 p)
{
    return rotate_x(rotate_y(rotate_z(p, -radians(rotation_z)), -radians(rotation_y)), -radians(rotation_x));
}

float4 mainImage(VertData v_in) : TARGET
{
    float2 mask_size = max(uv_size, float2(1.0, 1.0));
    float aspect = mask_size.x / mask_size.y;
    float fit = min(1.7 / max(aspect, 1.0), 1.7 / max(1.0 / aspect, 1.0));
    float object_scale = max(scale * fit, 0.001);
    float half_depth = max(thickness, 0.001) * 0.5;

    float2 screen = (v_in.uv * 2.0 - 1.0);
    screen.x *= uv_size.x / max(uv_size.y, 1.0);
    float3 camera_origin = float3(0.0, 0.0, 3.2);
    float3 camera_ray = normalize(float3(screen, -2.8));

    // Transform the camera ray into the unrotated text volume.
    float3 ray_origin = inverse_rotate_object(camera_origin) / object_scale;
    float3 ray_direction = normalize(inverse_rotate_object(camera_ray));
    ray_origin.z -= 0.0;

    // Ray-march the text mask as an extruded alpha silhouette. Fixed small
    // steps avoid relying on unsupported arbitrary-string/glyph operations.
    float t = 0.0;
    float3 hit_pos = float3(0.0, 0.0, 0.0);
    float hit_alpha = 0.0;
    bool hit = false;
    const int STEPS = 112;
    const float STEP_SIZE = 0.045;

    for (int i = 0; i < STEPS; i++) {
        float3 p = ray_origin + ray_direction * t;
        if (p.z >= -half_depth && p.z <= half_depth && abs(p.y) <= 0.5 && abs(p.x) <= 0.5 * aspect) {
            float2 mask_uv = float2(p.x / aspect + 0.5, 0.5 + p.y);
            float alpha = Text_Mask.Sample(textureSampler, mask_uv).a;
            if (alpha >= threshold) {
                hit = true;
                hit_pos = p;
                hit_alpha = alpha;
                break;
            }
        }
        t += STEP_SIZE;
    }

    if (!hit)
        return image.Sample(textureSampler, v_in.uv);

    float2 hit_uv = float2(hit_pos.x / aspect + 0.5, 0.5 + hit_pos.y);
    float2 texel = 1.0 / max(uv_size, float2(1.0, 1.0));
    float alpha_left = Text_Mask.Sample(textureSampler, hit_uv - float2(texel.x, 0.0)).a;
    float alpha_right = Text_Mask.Sample(textureSampler, hit_uv + float2(texel.x, 0.0)).a;
    float alpha_up = Text_Mask.Sample(textureSampler, hit_uv - float2(0.0, texel.y)).a;
    float alpha_down = Text_Mask.Sample(textureSampler, hit_uv + float2(0.0, texel.y)).a;
    float2 edge_gradient = float2(alpha_right - alpha_left, alpha_up - alpha_down);

    float3 local_normal;
    bool front_face = (half_depth - hit_pos.z) < STEP_SIZE * 1.5;
    if (front_face) {
        local_normal = float3(0.0, 0.0, 1.0);
    } else {
        local_normal = normalize(float3(-edge_gradient.x, -edge_gradient.y, 0.0) + float3(0.0001, 0.0001, 0.0));
    }

    float3 normal = normalize(rotate_object(local_normal));
    float3 light_direction = normalize(float3(-0.45, 0.65, 1.0));
    float diffuse = max(dot(normal, light_direction), 0.0);
    float lighting = 0.32 + 0.68 * diffuse;
    float3 color = front_face ? face_color.rgb : side_color.rgb;
    color *= lighting;

    // Keep the threshold edge antialiased against transparent output.
    float edge_width = max(length(edge_gradient) * 0.25, 0.02);
    float coverage = smoothstep(threshold - edge_width, threshold + edge_width, hit_alpha);
    float text_alpha = coverage * (front_face ? face_color.a : side_color.a);
    float4 base = image.Sample(textureSampler, v_in.uv);
    float out_alpha = text_alpha + base.a * (1.0 - text_alpha);
    float3 out_rgb = (color * text_alpha + base.rgb * base.a * (1.0 - text_alpha)) / max(out_alpha, 0.0001);
    return float4(out_rgb, out_alpha);
}
