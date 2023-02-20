SRC_VERT :: #string GLSL
#version 430 core
layout (location = 0) in vec3 a_pos;
layout (location = 1) in vec2 a_uv;
layout (location = 2) in vec3 a_norm;

uniform mat4 u_transform;

out struct Vert_Out {
	vec3 pos;
	vec2 uv;
	vec3 norm;
} vert_out;

void main() {
	vert_out.pos = a_pos;
	vert_out.uv = a_uv;
	vert_out.norm = a_norm;
	gl_Position = u_transform * vec4(a_pos, 1);
}
GLSL
SRC_CALCULATE_NORMALS_GEOM :: #string GLSL
#version 430 core
layout (triangles) in;
layout (triangle_strip, max_vertices=3) out;

uniform mat4 u_transform;

in struct Vert_Out {
	vec3 pos;
	vec2 uv;
	vec3 norm;
} vert_out[];

out struct Geom_Out {
	vec3 pos;
	vec2 uv;
	vec3 norm;	
} geom_out;

void main() {
	geom_out.norm = normalize(cross(
		vert_out[0].pos - vert_out[1].pos,
		vert_out[0].pos - vert_out[2].pos 
	));

	for(int i = 0; i < 3; i++) {
		gl_Position = u_transform * vec4(vert_out[i].pos, 1);
		geom_out.pos = vert_out[i].pos;
		geom_out.uv = vert_out[i].uv;
		EmitVertex();
	}
	EndPrimitive();
}
GLSL
SRC_DRAW_NORMALS_FRAG :: #string GLSL
#version 430 core

// in struct Geom_Out {
// 	vec3 pos;
// 	vec2 uv;
// 	vec3 norm;	
// } geom_out;

in struct Vert_Out {
	vec3 pos;
	vec2 uv;
	vec3 norm;
} vert_out;

out vec4 o_color;
uniform mat4 u_transform;

void main() {
	o_color = vec4(normalize(vert_out.norm) * .5 + .5, 1);
}
GLSL