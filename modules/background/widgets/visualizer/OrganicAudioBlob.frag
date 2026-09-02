#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float spin;
    float energy;
    float onset;
    float amplitude;
    float reveal;
    float deformationStrength;
    float glowStrength;
    vec4 bandsA;
    vec4 bandsB;
    vec4 bandsC;
    vec4 peaksA;
    vec4 peaksB;
    vec4 peaksC;
    vec4 primaryColor;
    vec4 secondaryColor;
    vec4 tertiaryColor;
} ubuf;

const float TAU = 6.28318530718;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    return 0.56 * noise(p)
        + 0.29 * noise(p * 2.03 + vec2(4.7, 11.3))
        + 0.15 * noise(p * 4.07 + vec2(17.1, 3.2));
}

float sample12(vec4 a, vec4 b, vec4 c, int index) {
    int i = index - (index / 12) * 12;
    if (i < 4)
        return a[i];
    if (i < 8)
        return b[i - 4];
    return c[i - 8];
}

float angularSpectrum(float angle, vec4 a, vec4 b, vec4 c) {
    float position = fract(angle / TAU + 0.5) * 12.0;
    int base = int(floor(position));
    float blend = smoothstep(0.0, 1.0, fract(position));
    float current = sample12(a, b, c, base);
    float next = sample12(a, b, c, base + 1);
    return mix(current, next, blend);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0;
    float r = length(p);
    vec2 dir = r > 0.0001 ? p / r : vec2(1.0, 0.0);

    float cs = cos(ubuf.spin);
    float sn = sin(ubuf.spin);
    dir = vec2(dir.x * cs - dir.y * sn, dir.x * sn + dir.y * cs);

    float t = ubuf.phase * TAU;
    vec2 orbitA = vec2(cos(t), sin(t)) * 0.95;
    vec2 orbitB = vec2(cos(t * 1.9 + 1.7), sin(t * 1.9 + 1.7)) * 0.55;
    float n1 = fbm(dir * 1.45 + orbitA);
    float n2 = fbm(dir * 2.25 + orbitB);
    float organic = smoothstep(0.27, 0.73, mix(n1, n2, 0.34));

    float angle = atan(dir.y, dir.x);
    float liveSpectrum = angularSpectrum(angle, ubuf.bandsA, ubuf.bandsB, ubuf.bandsC);
    float peakSpectrum = angularSpectrum(angle, ubuf.peaksA, ubuf.peaksB, ubuf.peaksC);
    float spectrum = mix(liveSpectrum, peakSpectrum, 0.18);
    float shapedSpectrum = pow(clamp(spectrum, 0.0, 1.0), 0.72);

    float rangeScale = mix(0.72, 1.36, clamp(ubuf.amplitude, 0.0, 1.0));
    float motionScale = rangeScale * ubuf.deformationStrength;
    float centeredSpectrum = shapedSpectrum - ubuf.energy * 0.64;
    float spectrumPush = centeredSpectrum * 0.50 * motionScale
        + shapedSpectrum * 0.115 * motionScale;
    spectrumPush += ubuf.onset * (0.040 + shapedSpectrum * 0.110) * motionScale;
    spectrumPush = clamp(spectrumPush, -0.060, 0.35);

    float baseRadius = 0.645;
    float contour = (organic - 0.5) * (0.024 + 0.018 * ubuf.energy);
    float microMotion = sin(angle * 4.0 + t * 0.22) * 0.008 * ubuf.energy;
    float blobRadius = min(0.965, baseRadius + contour + microMotion + spectrumPush);

    float aa = max(fwidth(r) * 1.5, 0.0025);
    float body = 1.0 - smoothstep(blobRadius - aa, blobRadius + aa, r);
    float innerRadius = 0.565;
    float innerFade = smoothstep(innerRadius - 0.035, innerRadius + 0.018, r);
    float edgeDistance = max(0.0, r - blobRadius);
    float halo = exp(-edgeDistance * mix(34.0, 18.0, ubuf.glowStrength)) * (1.0 - body)
        * ubuf.glowStrength * (0.06 + ubuf.energy * 0.14 + ubuf.onset * 0.12);

    float depth = clamp(1.0 - r / max(blobRadius, 0.001), 0.0, 1.0);
    float chroma = clamp(0.22 + depth * 0.64 + organic * 0.18, 0.0, 1.0);
    float huePhase = fract(angle / TAU + 0.5 + ubuf.phase * 0.035);
    vec3 paletteColor;
    if (huePhase < 0.3333333) {
        paletteColor = mix(ubuf.primaryColor.rgb, ubuf.secondaryColor.rgb,
            huePhase * 3.0);
    } else if (huePhase < 0.6666667) {
        paletteColor = mix(ubuf.secondaryColor.rgb, ubuf.tertiaryColor.rgb,
            (huePhase - 0.3333333) * 3.0);
    } else {
        paletteColor = mix(ubuf.tertiaryColor.rgb, ubuf.primaryColor.rgb,
            (huePhase - 0.6666667) * 3.0);
    }
    vec3 bodyColor = mix(paletteColor, ubuf.primaryColor.rgb, chroma * 0.28);
    bodyColor *= 0.88 + depth * 0.12 + shapedSpectrum * 0.24;

    vec3 haloColor = mix(paletteColor, ubuf.secondaryColor.rgb, 0.22);
    float ringBody = body * innerFade;
    float localAlpha = 0.40 + shapedSpectrum * 0.42 + ubuf.onset * 0.10;
    float alpha = ringBody * min(0.92, localAlpha) + halo;
    vec3 rgb = bodyColor * ringBody + haloColor * halo;

    float sourceAlpha = min(1.0, max(max(ubuf.primaryColor.a, ubuf.secondaryColor.a), ubuf.tertiaryColor.a));
    float revealAlpha = smoothstep(0.0, 0.35, ubuf.reveal);
    alpha *= sourceAlpha * ubuf.qt_Opacity * revealAlpha;
    rgb *= sourceAlpha * ubuf.qt_Opacity * revealAlpha;
    fragColor = vec4(rgb, alpha);
}
