extern number time;
extern vec2 resolution;

vec4 effect(vec4 color, Image texture, vec2 tc, vec2 pc) {
    vec2 uv = tc;
    
    // Scanlines suaves
    float scanline = sin(uv.y * resolution.y * 1.5) * 0.04;
    
    // Curvatura de pantalla
    vec2 curved = uv * 2.0 - 1.0;
    curved *= 1.0 + 0.05 * (curved.x * curved.x + curved.y * curved.y);
    curved = (curved + 1.0) * 0.5;
    
    // Viñeta
    float vignette = 1.0 - length(curved - 0.5) * 0.8;
    
    // Color base con aberración cromática
    vec4 col = Texel(texture, curved);
    float distortion = 0.002;
    col.r = Texel(texture, curved + vec2(distortion, 0.0)).r;
    col.b = Texel(texture, curved - vec2(distortion, 0.0)).b;
    
    // Flicker sutil
    float flicker = 0.98 + 0.02 * sin(time * 20.0);
    
    // Aplicar efectos
    col.rgb *= (1.0 - scanline) * vignette * flicker;
    
    // Bordes negros fuera del área curva
    if (curved.x < 0.0 || curved.x > 1.0 || curved.y < 0.0 || curved.y > 1.0) {
        col = vec4(0.0, 0.0, 0.0, 1.0);
    }
    
    return col * color;
}