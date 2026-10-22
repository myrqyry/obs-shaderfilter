
// lib_spatial.shader
// UV Manipulation

// Rotate UV coordinates around a pivot point
// angle is in radians
float2 rotateUV(float2 uv, float angle, float2 pivot) {
    float s = sin(angle);
    float c = cos(angle);
    
    // Move UV to origin relative to pivot
    uv -= pivot;
    
    // Rotate
    float2 newUV;
    newUV.x = uv.x * c - uv.y * s;
    newUV.y = uv.x * s + uv.y * c;
    
    // Move back
    newUV += pivot;
    
    return newUV;
}

// Correct UVs for aspect ratio (Useful for drawing perfect circles)
// Returns UVs where X is adjusted to match screen width
float2 fixAspect(float2 uv, float2 size) {
    float aspect = size.x / size.y;
    uv.x *= aspect;
    return uv;
}

// Zoom into the center of the UVs
// Amount > 1.0 zooms in, < 1.0 zooms out
float2 zoomUV(float2 uv, float amount, float2 pivot) {
    return (uv - pivot) / amount + pivot;
}