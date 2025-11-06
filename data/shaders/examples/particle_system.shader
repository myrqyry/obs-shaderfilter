// particle_system.shader - Dynamic particle effects
#define vec2 float2
#define vec3 float3
#define vec4 float4

uniform int Particle_Count<
    string label = "Particle Count";
    string widget_type = "slider";
    int minimum = 10;
    int maximum = 200;
    int step = 5;
> = 50;

uniform float Particle_Size<
    string label = "Particle Size";
    string widget_type = "slider";
    float minimum = 0.5;
    float maximum = 10.0;
    float step = 0.1;
> = 2.0;

uniform float Speed<
    string label = "Animation Speed";
    string widget_type = "slider";
    float minimum = 0.1;
    float maximum = 5.0;
    float step = 0.1;
> = 1.0;

uniform float4 Particle_Color<
    string label = "Particle Color";
> = {1.0, 1.0, 1.0, 0.8};

uniform bool Apply_To_Source<
    string label = "Apply to Source";
> = false;

// Improved random function
float rand(float2 co) {
    return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
}

// Particle simulation
float4 simulate_particles(float2 uv, float time) {
    float4 particles = float4(0, 0, 0, 0);

    for (int i = 0; i < Particle_Count; i++) {
        float2 seed = float2(i * 0.1, i * 0.2);

        // Particle position with movement
        float2 pos = float2(
            rand(seed) + sin(time * Speed + i * 0.5) * 0.1,
            frac(rand(seed + 0.5) + time * Speed * 0.3)
        );

        // Wrap particles
        pos.x = frac(pos.x);
        pos.y = frac(pos.y);

        // Distance to particle
        float dist = distance(uv, pos);

        // Particle influence
        float influence = 1.0 - smoothstep(0.0, Particle_Size * 0.01, dist);
        influence = pow(influence, 2.0);

        // Add particle contribution
        particles += Particle_Color * influence;
    }

    return particles;
}

float4 mainImage(VertData v_in) : TARGET {
    float4 original = image.Sample(textureSampler, v_in.uv);
    float4 particles = simulate_particles(v_in.uv, elapsed_time);

    if (Apply_To_Source) {
        // Blend particles with source
        return lerp(original, particles, particles.a);
    } else {
        // Particles only
        return particles;
    }
}
