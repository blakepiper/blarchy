#version 300 es

precision mediump float;

in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

// Brighter green-forward profile for red-tinted lenses. This intentionally
// overdrives the display: the glasses absorb much of the green and blue light,
// so a dim-looking correction is not useful when viewed through the lenses.
const vec3 COMPENSATION_GAINS = vec3(1.15, 2.40, 1.70);
const float BRIGHTNESS_BOOST = 1.30;
const float COMPENSATION_STRENGTH = 1.0;

void main() {
  vec4 pixel = texture(tex, v_texcoord);
  vec3 compensated = pixel.rgb * COMPENSATION_GAINS * BRIGHTNESS_BOOST;
  compensated = clamp(compensated, 0.0, 1.0);
  fragColor = vec4(mix(pixel.rgb, compensated, COMPENSATION_STRENGTH), pixel.a);
}
