// Glyph Garden — a playful, self-contained OBS ShaderFilter .shader.
// An original sibling of the author's bitmap25 and Bitmap Glyph Motion.
// By myrqyry + Aster; six newly drawn 5x5 families.
// No external files or preprocessor includes; safe to place in Downloads.
// Load as a Shaderfilter Filter with Override Entire Effect OFF.
// OBS supplies image, textureSampler, VertData, uv_size, elapsed_time, Draw.

// Local subset of data/stdlib/colors.glsl. Intentionally standalone:
// users can load this .shader from Downloads without adjacent assets.
#define blend_min3(a, b, c) min(min(a, b), c)
#define blend_max3(a, b, c) max(max(a, b), c)

float blendLuminance(float3 c) {
    return 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
}

float3 blendSetLum(float3 c, float l) {
    // ClipColor from the non-separable blend specification. Black and white
    // targets are fixed points; never divide by l or 1-l at those endpoints.
    if (l <= 0.0) return float3(0.0, 0.0, 0.0);
    if (l >= 1.0) return float3(1.0, 1.0, 1.0);
    float3 r = c + (l - blendLuminance(c));
    float mn = blend_min3(r.r, r.g, r.b);
    if (mn < 0.0) r = l + (r - l) * (l / (l - mn));
    float mx = blend_max3(r.r, r.g, r.b);
    if (mx > 1.0) r = l + (r - l) * ((1.0 - l) / (mx - l));
    return saturate(r);
}

float blendSaturation(float3 c) {
    return blend_max3(c.r, c.g, c.b) - blend_min3(c.r, c.g, c.b);
}

float3 blendSetSat(float3 c, float s) {
    float mn = blend_min3(c.r, c.g, c.b);
    float mx = blend_max3(c.r, c.g, c.b);
    return (mx > mn) ? (c - mn) * s / (mx - mn) : float3(0.0, 0.0, 0.0);
}

float3 blendMultiply(float3 base, float3 blend) {
    return base * blend;
}

float3 blendScreen(float3 base, float3 blend) {
    return 1.0 - (1.0 - base) * (1.0 - blend);
}

float3 blendOverlay(float3 base, float3 blend) {
    float3 r;
    r.r = (base.r < 0.5) ? 2.0 * base.r * blend.r : 1.0 - 2.0 * (1.0 - base.r) * (1.0 - blend.r);
    r.g = (base.g < 0.5) ? 2.0 * base.g * blend.g : 1.0 - 2.0 * (1.0 - base.g) * (1.0 - blend.g);
    r.b = (base.b < 0.5) ? 2.0 * base.b * blend.b : 1.0 - 2.0 * (1.0 - base.b) * (1.0 - blend.b);
    return r;
}

float sqrtSafe(float x) { return sqrt(max(x, 0.0)); }

float3 blendSoftLight(float3 base, float3 blend) {
    float3 r;
    r.r = (blend.r < 0.5)
        ? base.r - (1.0 - 2.0 * blend.r) * base.r * (1.0 - base.r)
        : base.r + (2.0 * blend.r - 1.0) * (sqrtSafe(base.r) - base.r);
    r.g = (blend.g < 0.5)
        ? base.g - (1.0 - 2.0 * blend.g) * base.g * (1.0 - base.g)
        : base.g + (2.0 * blend.g - 1.0) * (sqrtSafe(base.g) - base.g);
    r.b = (blend.b < 0.5)
        ? base.b - (1.0 - 2.0 * blend.b) * base.b * (1.0 - base.b)
        : base.b + (2.0 * blend.b - 1.0) * (sqrtSafe(base.b) - base.b);
    return r;
}

float3 blendHue(float3 base, float3 blend) {
    return blendSetLum(blendSetSat(blend, blendSaturation(base)), blendLuminance(base));
}

float3 blendColor(float3 base, float3 blend) {
    return blendSetLum(blend, blendLuminance(base));
}



uniform string GardenNote<
    string widget_type = "info";
> = "GLYPH GARDEN | six drawn symbol families, living rigid-cell mosaics";

uniform float Mix<
    string label = "Effect Mix";
    string group = "Appearance";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

uniform float Glyph_Pixels<
    string label = "Glyph Size (pixels)";
    string group = "Grid and Spacing";
    string widget_type = "slider";
    float minimum = 5.0;
    float maximum = 48.0;
    float step = 1.0;
> = 14.0;

uniform float Gap_Pixels<
    string label = "Space Between Glyphs (pixels)";
    string group = "Grid and Spacing";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 40.0;
    float step = 1.0;
> = 4.0;

uniform float2 Grid_Offset<
    string label = "Grid Offset (pixels)";
    string group = "Grid and Spacing";
    float2 minimum = {-50.0, -50.0};
    float2 maximum = {50.0, 50.0};
    float2 step = {1.0, 1.0};
> = {0.0, 0.0};

uniform float Grid_Line_Opacity<
    string label = "Fine Grid Lines";
    string group = "Grid and Spacing";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.0;

uniform bool Random_Quarter_Turns<
    string label = "Stable Quarter-Turn Glyphs";
    string group = "Grid and Spacing";
> = false;

uniform int Glyph_Set_A<
    string label = "Primary Glyph Family";
    string group = "Glyph Families";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Petal Garden";
    int option_1_value = 1;
    string option_1_label = "Starlight";
    int option_2_value = 2;
    string option_2_label = "Circuitry";
    int option_3_value = 3;
    string option_3_label = "Ink Strokes";
    int option_4_value = 4;
    string option_4_label = "Constellation";
    int option_5_value = 5;
    string option_5_label = "Toy Blocks";
> = 0;

uniform bool Dual_Set<
    string label = "Shadows and Highlights Use Different Sets";
    string group = "Glyph Families";
> = true;

uniform int Glyph_Set_B<
    string label = "Highlight Glyph Family";
    string group = "Glyph Families";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Petal Garden";
    int option_1_value = 1;
    string option_1_label = "Starlight";
    int option_2_value = 2;
    string option_2_label = "Circuitry";
    int option_3_value = 3;
    string option_3_label = "Ink Strokes";
    int option_4_value = 4;
    string option_4_label = "Constellation";
    int option_5_value = 5;
    string option_5_label = "Toy Blocks";
> = 1;

uniform float Tone_Split<
    string label = "Family Split at Brightness";
    string group = "Glyph Families";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.54;

uniform float Split_Softness<
    string label = "Family Crossfade Width";
    string group = "Glyph Families";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 0.5;
    float step = 0.01;
> = 0.13;

uniform float Tone_Low<
    string label = "Shadow Threshold";
    string group = "Tone";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.04;

uniform float Tone_High<
    string label = "Highlight Threshold";
    string group = "Tone";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.95;

uniform float Tone_Curve<
    string label = "Glyph Density Curve";
    string group = "Tone";
    string widget_type = "slider";
    float minimum = 0.25;
    float maximum = 3.0;
    float step = 0.05;
> = 1.0;

uniform int Ink_Mode<
    string label = "Ink Color";
    string group = "Color";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Source Image";
    int option_1_value = 1;
    string option_1_label = "Single Ink";
    int option_2_value = 2;
    string option_2_label = "Duotone";
    int option_3_value = 3;
    string option_3_label = "Triad";
> = 2;

uniform float4 Ink_Color<
    string label = "Petal Ink";
    string group = "Color";
> = {1.0, 0.70, 0.79, 1.0};

uniform float4 Accent_Color<
    string label = "Spark Ink";
    string group = "Color";
> = {0.52, 0.88, 0.87, 1.0};

uniform float4 Mid_Color<
    string label = "Mid Ink";
    string group = "Color";
> = {0.82, 0.69, 0.99, 1.0};

uniform float4 Backdrop_Color<
    string label = "Backdrop Color";
    string group = "Color";
> = {0.065, 0.047, 0.100, 1.0};

uniform float Background_Source<
    string label = "Original Image Behind Glyphs";
    string group = "Color";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 0.38;

uniform float Ink_Opacity<
    string label = "Glyph Opacity";
    string group = "Color";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 1.0;
    float step = 0.01;
> = 1.0;

uniform int Blend_Mode<
    string label = "Ink Blend Mode";
    string group = "Color";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Normal";
    int option_1_value = 1;
    string option_1_label = "Multiply";
    int option_2_value = 2;
    string option_2_label = "Screen";
    int option_3_value = 3;
    string option_3_label = "Overlay";
    int option_4_value = 4;
    string option_4_label = "Soft Light";
    int option_5_value = 5;
    string option_5_label = "Color";
    int option_6_value = 6;
    string option_6_label = "Hue";
> = 0;

uniform bool Animate<
    string label = "Animate Grid";
    string group = "Motion";
> = true;

uniform int Motion_Mode<
    string label = "Grid Motion";
    string group = "Motion";
    string widget_type = "select";
    int option_0_value = 0;
    string option_0_label = "Still";
    int option_1_value = 1;
    string option_1_label = "Drift Horizontal";
    int option_2_value = 2;
    string option_2_label = "Drift Vertical";
    int option_3_value = 3;
    string option_3_label = "Orbit";
    int option_4_value = 4;
    string option_4_label = "Row Wave";
    int option_5_value = 5;
    string option_5_label = "Column Wave";
    int option_6_value = 6;
    string option_6_label = "Checker Dance";
    int option_7_value = 7;
    string option_7_label = "Breeze Rows";
    int option_8_value = 8;
    string option_8_label = "Snap Steps";
    int option_9_value = 9;
    string option_9_label = "Parallax Bands";
> = 3;

uniform float Motion_Pixels<
    string label = "Motion Distance (px)";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 80.0;
    float step = 1.0;
> = 14.0;

uniform float Motion_Speed<
    string label = "Motion Speed";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 0.0;
    float maximum = 5.0;
    float step = 0.05;
> = 0.75;

uniform float Wave_Length<
    string label = "Wavelength (cells)";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 2.0;
    float maximum = 28.0;
    float step = 1.0;
> = 8.0;

uniform float Snap_Rate<
    string label = "Steps per Second";
    string group = "Motion";
    string widget_type = "slider";
    float minimum = 1.0;
    float maximum = 20.0;
    float step = 1.0;
> = 5.0;

// Authored 5x5 bitmaps: 6 families x 5 tone steps.
// The # marks below show each original pixel design.
int GardenBits(int family, int tone)
{
    if (tone <= 0) return 0;
    if (family == 0) { // Petal Garden
        // ..... / ..... / ..#.. / ..... / .....
        if (tone == 1) return 4096;
        // ..... / ..#.. / .###. / ..#.. / .....
        if (tone == 2) return 145536;
        // ..#.. / .###. / ##### / .###. / ..#..
        if (tone == 3) return 4685252;
        // #.#.# / .###. / ##### / .###. / #.#.#
        if (tone == 4) return 22511061;
        // .###. / ##### / ##.## / ##### / .###.
        if (tone == 5) return 15724526;
    }
    if (family == 1) { // Starlight
        // ..... / ..... / ..#.. / ..... / .....
        if (tone == 1) return 4096;
        // ..... / ..#.. / .###. / ..#.. / .....
        if (tone == 2) return 145536;
        // #...# / .#.#. / ..#.. / .#.#. / #...#
        if (tone == 3) return 18157905;
        // ..#.. / #.#.# / .###. / #.#.# / ..#..
        if (tone == 4) return 4897444;
        // #.#.# / .###. / ##### / .###. / #.#.#
        if (tone == 5) return 22511061;
    }
    if (family == 2) { // Circuitry
        // ..... / ..... / ..#.. / ..... / .....
        if (tone == 1) return 4096;
        // ..#.. / ..#.. / ..### / ..... / .....
        if (tone == 2) return 28804;
        // ..#.. / .###. / .#.#. / ...#. / ...#.
        if (tone == 3) return 8661444;
        // #.#.# / ##### / ..#.. / ##### / #.#.#
        if (tone == 4) return 23041013;
        // ##### / #...# / #.#.# / #...# / #####
        if (tone == 5) return 33084991;
    }
    if (family == 3) { // Ink Strokes
        // ..... / ..... / .##.. / ..... / .....
        if (tone == 1) return 6144;
        // ..... / ..##. / .##.. / ..... / .....
        if (tone == 2) return 6528;
        // ...## / ..##. / .##.. / ##... / .....
        if (tone == 3) return 104856;
        // ##..# / .##.. / ..##. / .##.. / #..##
        if (tone == 4) return 26423507;
        // ##.## / ####. / .###. / ####. / ##.##
        if (tone == 5) return 28817915;
    }
    if (family == 4) { // Constellation
        // ..... / ..... / ..#.. / ..... / .....
        if (tone == 1) return 4096;
        // ..#.. / ..... / ....# / ..... / ..#..
        if (tone == 2) return 4210692;
        // #...# / .#... / ..#.. / ...#. / #...#
        if (tone == 3) return 18092113;
        // #.#.# / ..... / ..#.. / ..... / #.#.#
        if (tone == 4) return 22024213;
        // #.#.# / .###. / ##### / .###. / #.#.#
        if (tone == 5) return 22511061;
    }
    if (family == 5) { // Toy Blocks
        // ..... / ..... / ..#.. / ..... / .....
        if (tone == 1) return 4096;
        // ..... / .###. / .###. / .###. / .....
        if (tone == 2) return 473536;
        // ##... / ##... / ..... / ...## / ...##
        if (tone == 3) return 25952355;
        // #.#.# / .###. / #.#.# / .###. / #.#.#
        if (tone == 4) return 22500821;
        // ##### / ##.## / ##### / ##.## / #####
        if (tone == 5) return 33423231;
    }
    return 0;
}


float GardenHash(float2 v)
{
    return frac(sin(dot(v, float2(127.1, 311.7))) * 43758.5453);
}
float2 GardenRotateCell(float2 p, float angleStep)
{
    if (angleStep < 0.5) return p;
    if (angleStep < 1.5) return float2(1.0-p.y,p.x);
    if (angleStep < 2.5) return 1.0-p;
    return float2(p.y,1.0-p.x);
}
float GardenMask(int bits, float2 uv)
{
    if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0)
        return 0.0;
    int2 pos = int2(floor(uv*5.0));
    return float((bits >> (pos.x + pos.y * 5)) & 1);
}
float3 GardenBlend(float3 base, float3 ink)
{
    if (Blend_Mode == 1) return blendMultiply(base, ink);
    if (Blend_Mode == 2) return blendScreen(base, ink);
    if (Blend_Mode == 3) return blendOverlay(base, ink);
    if (Blend_Mode == 4) return blendSoftLight(base, ink);
    if (Blend_Mode == 5) return blendColor(base, ink);
    if (Blend_Mode == 6) return blendHue(base, ink);
    return ink;
}
float2 GardenMotion(float2 pixel, float pitch, float time)
{
    if (!Animate || Motion_Mode == 0 || Motion_Pixels <= 0.0)
        return float2(0.0, 0.0);
    float t=time*max(Motion_Speed,0.0);
    float amp=Motion_Pixels;
    float row=floor(pixel.y / pitch);
    float col=floor(pixel.x / pitch);
    float wl=max(Wave_Length,2.0);
    if (Motion_Mode == 1) return float2(t*amp,0.0);
    if (Motion_Mode == 2) return float2(0.0,t*amp);
    if (Motion_Mode == 3) return float2(sin(t)*amp, cos(t)*amp);
    if (Motion_Mode == 4) return float2(sin(t + row*6.2831853/wl)*amp,0.0);
    if (Motion_Mode == 5) return float2(0.0,sin(t + col*6.2831853/wl)*amp);
    if (Motion_Mode == 6) return float2(0.0,0.0);
    if (Motion_Mode == 7)
        return float2(sin(t+row*0.41+GardenHash(float2(row,2.0))*6.28318)*amp,0.0);
    if (Motion_Mode == 8) {
        float clock=floor(t*max(Snap_Rate,1.0))/max(Snap_Rate,1.0);
        return float2(sin(clock)*amp, cos(clock*0.71)*amp);
    }
    if (Motion_Mode == 9)
        return float2(t*amp*(0.18+0.22*fmod(abs(row),4.0)),0.0);
    return float2(0.0,0.0);
}
float4 mainImage(VertData v_in):TARGET
{
    float4 original=image.Sample(textureSampler,v_in.uv);
    if (Mix<=0.0) return original;

    float size=max(Glyph_Pixels,5.0);
    float gap=max(Gap_Pixels,0.0);
    float pitch=size+gap;
    float2 resolution=max(uv_size,float2(1.0,1.0));
    float2 pixel=v_in.uv*resolution+Grid_Offset;
    float2 shift=GardenMotion(pixel,pitch,elapsed_time);

    // Row and column waves use constant offsets across a cell stripe.
    // For those modes, never sample a pixel-dependent warp inside a glyph.
    float2 mapped=pixel+shift;
    float2 cell=floor(mapped/pitch);
    float2 local=mapped-cell*pitch;

    // Checker Dance animates glyphs *inside* their fixed, spaced cells.
    // Displacement is bounded by the gap, so tile geometry stays stable.
    if (Animate && Motion_Mode==6 && gap>0.0) {
        float odd=fmod(abs(cell.x+cell.y),2.0);
        float signValue=odd<0.5?-1.0:1.0;
        float wiggle=min(Motion_Pixels,gap*0.48);
        float t=elapsed_time*max(Motion_Speed,0.0);
        local-=float2(sin(t),cos(t*0.81))*wiggle*signValue;
    }
    float2 cellUV=(local-gap*0.5)/size;
    if (Random_Quarter_Turns)
        cellUV=GardenRotateCell(cellUV,floor(GardenHash(cell)*4.0));

    // Sample each cell center (in source coordinates). This is independent
    // of the glyph's local UV so no glyph is distorted by motion.
    float2 sourceUV=((cell+0.5)*pitch-shift-Grid_Offset)/resolution;
    float4 sampled=image.Sample(textureSampler,saturate(sourceUV));
    float luma=dot(sampled.rgb,float3(0.2126,0.7152,0.0722));
    float tone=saturate((luma-Tone_Low)/max(Tone_High-Tone_Low,0.001));
    tone=pow(tone,max(Tone_Curve,0.25));
    int level=0;
    if (tone>0.0) level=min(5,1+int(floor(tone*5.0)));

    float maskA=GardenMask(GardenBits(clamp(Glyph_Set_A,0,5),level),cellUV);
    float mask=maskA;
    if (Dual_Set) {
        float maskB=GardenMask(GardenBits(clamp(Glyph_Set_B,0,5),level),cellUV);
        float width=max(Split_Softness,0.001);
        float amount=smoothstep(Tone_Split-width*0.5,Tone_Split+width*0.5,tone);
        mask=lerp(maskA,maskB,amount);
    }

    float3 under=lerp(Backdrop_Color.rgb,original.rgb,saturate(Background_Source));
    float3 ink=sampled.rgb;
    if (Ink_Mode == 1) ink=Ink_Color.rgb;
    if (Ink_Mode == 2) ink=lerp(Ink_Color.rgb,Accent_Color.rgb,tone);
    if (Ink_Mode == 3) {
        if (tone<0.5) ink=lerp(Ink_Color.rgb,Mid_Color.rgb,tone*2.0);
        else ink=lerp(Mid_Color.rgb,Accent_Color.rgb,(tone-0.5)*2.0);
    }
    float3 result=lerp(under,GardenBlend(under,saturate(ink)),saturate(mask*Ink_Opacity));

    // Optional hairline at outer tile boundaries. Spacing is true empty
    // background surrounding a centered glyph, never a resized glyph.
    if (Grid_Line_Opacity>0.0) {
        float edge=min(min(local.x,pitch-local.x),min(local.y,pitch-local.y));
        float hairline=1.0-smoothstep(0.2,1.2,edge);
        result=lerp(result,Accent_Color.rgb,hairline*saturate(Grid_Line_Opacity)*0.35);
    }

    return float4(lerp(original.rgb,saturate(result),saturate(Mix)),original.a);
}
