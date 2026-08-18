#version 300 es

precision mediump float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

// Starter profile for moderately red-tinted lenses. The blue channel is the
// reference channel; red and green are reduced before the lens so their
// stronger transmission does not dominate the image behind the glasses.
const vec3 COMPENSATION_GAINS = vec3(0.20, 0.60, 1.00);
const float COMPENSATION_STRENGTH = 1.0;

float srgb_to_linear(float value) {
  return value <= 0.04045
    ? value / 12.92
    : pow((value + 0.055) / 1.055, 2.4);
}

float linear_to_srgb(float value) {
  return value <= 0.0031308
    ? value * 12.92
    : 1.055 * pow(value, 1.0 / 2.4) - 0.055;
}

vec3 srgb_to_linear(vec3 value) {
  return vec3(
    srgb_to_linear(value.r),
    srgb_to_linear(value.g),
    srgb_to_linear(value.b)
  );
}

vec3 linear_to_srgb(vec3 value) {
  return vec3(
    linear_to_srgb(value.r),
    linear_to_srgb(value.g),
    linear_to_srgb(value.b)
  );
}

void main() {
  vec4 pixel = texture(tex, v_texcoord);
  vec3 linear = srgb_to_linear(pixel.rgb);
  vec3 compensated = linear * COMPENSATION_GAINS;
  linear = mix(linear, compensated, COMPENSATION_STRENGTH);
  fragColor = vec4(clamp(linear_to_srgb(linear), 0.0, 1.0), pixel.a);
}
