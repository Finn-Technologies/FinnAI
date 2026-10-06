// The light of a live voice conversation (lib/src/features/chat/widgets/
// voice_glow.dart), in one pass: a Siri-style rim of colour round the screen
// and heavily blurred orbs rising from the bottom edge.
//
// Nothing here is blurred. Each pixel evaluates the Gaussian falloff of a
// handful of shapes directly, which is what a blurred shape looks like, so
// the softness costs a few dozen ALU ops per pixel and no offscreen layers,
// no filter passes and no extra memory.
#version 460 core

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uPhase;     // free-running time, in turns
uniform float uPresence;  // 0..1 how open voice mode is
uniform float uLevel;     // 0..1 loudness, smoothed
uniform float uThinking;  // 0..1
uniform float uDark;      // 1 on a dark canvas, 0 on a light one
uniform float uRadius;    // the rim's corner radius, in pixels

out vec4 fragColor;

const float TAU = 6.2831853;

// Siri's warm-to-cool run, in the brand's hues, as a smooth loop.
vec3 hue(float t) {
  t = fract(t) * 6.0;
  vec3 c0 = vec3(1.00, 0.42, 0.60);
  vec3 c1 = vec3(0.80, 0.42, 0.78);
  vec3 c2 = vec3(0.55, 0.23, 1.00);
  vec3 c3 = vec3(0.30, 0.49, 1.00);
  vec3 c4 = vec3(0.18, 0.83, 0.78);
  vec3 c5 = vec3(1.00, 0.60, 0.35);
  float f = smoothstep(0.0, 1.0, fract(t));
  if (t < 1.0) return mix(c0, c1, f);
  if (t < 2.0) return mix(c1, c2, f);
  if (t < 3.0) return mix(c2, c3, f);
  if (t < 4.0) return mix(c3, c4, f);
  if (t < 5.0) return mix(c4, c5, f);
  return mix(c5, c0, f);
}

float roundedBox(vec2 p, vec2 extent, float r) {
  vec2 q = abs(p) - extent + r;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float p = uPresence;
  if (p <= 0.001) {
    fragColor = vec4(0.0);
    return;
  }
  float w = uSize.x;
  float h = uSize.y;
  float level = clamp(uLevel, 0.0, 1.0);
  vec2 center = uSize * 0.5;
  vec2 rel = frag - center;

  // ---- The rim -----------------------------------------------------------
  // Distance in from the screen's rounded edge.
  float inset = abs(roundedBox(rel, center, uRadius));
  // 0 at the bottom centre, 1 at the top centre, either way round.
  float around = abs(atan(rel.x, rel.y)) / 3.14159265;
  // Draws itself in from the bottom, up both sides, meeting at the top.
  float reveal = smoothstep(0.0, 1.0, p);
  float shown = 1.0 - smoothstep(reveal * 1.08 - 0.08, reveal * 1.08, around);
  float spread = 16.0 + 26.0 * level + 10.0 * uThinking;
  float core = exp(-inset * inset / 18.0);
  float halo = exp(-inset / spread);
  float intensity = p * (0.55 + 0.45 * level + 0.15 * uThinking);
  float rimA = (core * 0.9 + halo * 0.55) * shown * intensity;
  vec3 rimC = hue(atan(rel.y, rel.x) / TAU + uPhase * 0.35);

  // ---- The orbs ------------------------------------------------------------
  float reach = h * (0.16 + 0.30 * level) * p;
  vec3 orbC = vec3(0.0);
  float orbA = 0.0;
  for (int i = 0; i < 5; i++) {
    float o = float(i) / 5.0;
    float drift = sin((uPhase + o) * TAU) * 0.16;
    float sweep = sin(uPhase * 2.2 * 3.14159265 + o * 6.0) * 0.3 * uThinking;
    float x = w * (0.1 + 0.8 * o + drift + sweep);
    float bob = cos((uPhase * 1.3 + o) * TAU);
    float radius = w * (0.5 + 0.14 * level + 0.05 * bob);
    float cy = h + radius * 0.35 - reach * (0.55 + 0.12 * bob);
    float stretch = max(1.0, (radius + reach) / (radius * 1.6));
    vec2 d = vec2(frag.x - x, (frag.y - cy) / stretch) / radius;
    float g = exp(-4.2 * dot(d, d));
    float a = g * (0.75 + 0.25 * sin(uPhase * 3.0 + float(i)));
    orbC += hue(o + uPhase * 0.1) * a;
    orbA += a;
  }
  float orbStrength = mix(0.5, 0.62, uDark) * p;
  vec3 orbs = orbC * orbStrength;
  float orbAlpha = clamp(orbA * orbStrength, 0.0, 1.0);

  // Dark: light adds to what is behind it. Light: colour lies over the
  // canvas like ink, at a strength that keeps text above it readable.
  vec3 rgb = rimC * rimA + orbs;
  float alpha = clamp(rimA + orbAlpha, 0.0, 1.0);
  if (uDark < 0.5) {
    rgb = rgb * 0.92;
    alpha = alpha * 0.85;
    rgb = min(rgb, vec3(alpha));
  }
  fragColor = vec4(rgb, alpha);
}
