SRC_VERT :: #string GLSL
#version 430 core
layout (location = 0) in vec3 a_pos;
layout (location = 1) in vec2 a_uv;

out vec2 uv;
void main() {
	gl_Position = vec4(a_pos, 1);
	uv = a_uv;
}
GLSL
SRC_FRAG :: #string GLSL
#version 430 core

in vec2 uv;
out vec4 o_color;

void main() {
	o_color = vec4(uv, 0, 1);
}
GLSL