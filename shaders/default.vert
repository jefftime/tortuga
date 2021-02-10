#version 450

layout (location = 0) in vec3 position;
layout (location = 1) in vec3 color;

layout (location = 0) out vec4 out_color;

layout (binding = 0) uniform Uniforms {
  vec3 color;
  mat4 m;
} u;

void main(void) {
  gl_Position = vec4(position, 1.0);
  out_color = vec4(u.m[0]);
}
