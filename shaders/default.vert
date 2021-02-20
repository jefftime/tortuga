#version 450

layout (location = 0) in vec3 position;
layout (location = 1) in float index;

layout (location = 0) out vec4 out_color;

layout (binding = 0) uniform Uniforms {
  vec3 colors[4];
} u;

void main(void) {
  gl_Position = vec4(position, 1.0);
  out_color = vec4(u.colors[uint(index)], 1);
}
