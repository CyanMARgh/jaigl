SRC_VERT :: #string GLSL
#version 430 core
layout (location = 0) in vec3 a_pos;
layout (location = 1) in vec2 a_uv;

uniform mat4 u_transform;

// out vec2 uv;
out vec3 col;

void main() {
	col = a_pos + .5;
	// gl_Position = vec4(a_pos, 1);
	gl_Position = u_transform * vec4(a_pos, 1);
	// uv = a_uv;
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

// in vec2 uv;
in vec3 col;

out vec4 o_color;
uniform mat4 u_transform;

void main() {
	// float br = u_transform[int(4 * gl_FragCoord.x / 800)][int(4 * gl_FragCoord.y / 800)] / 15;
	o_color = vec4(col, 1);
	// o_color = vec4(gl_FragCoord.xy / vec2(800, 800), 0, 1);
	// o_color = vec4(uv, 0, 1);
	// o_color = texture(u_tex, uv);
	// o_color = vec4(vec3(gl_FragCoord.z), 1);
}
GLSL