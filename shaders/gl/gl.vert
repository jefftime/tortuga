#version 150 core

in vec3 pos;

out float color;

void main() {
  color = pos.z;
  gl_Position = vec4(pos.xy, 0.0, 1.0);
}
  
