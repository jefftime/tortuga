#version 150 core

in vec3 pos;
in vec3 col;

out vec3 color;

void main() {
  color = col;
  gl_Position = vec4(pos.xy, 0.0, 1.0);
}
  
