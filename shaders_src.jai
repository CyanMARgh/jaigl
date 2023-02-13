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

uniform float u_blue;
in vec2 uv;
out vec4 o_color;

void main() {
	o_color = vec4(uv, u_blue, 1);
}
GLSL

SRC_JUST_TEXTURE_FRAG :: #string GLSL
#version 430 core

layout(binding = 0) uniform sampler2D u_tex;
in vec2 uv;
out vec4 o_color;

void main() {
	o_color = texture(u_tex, uv);
}
GLSL