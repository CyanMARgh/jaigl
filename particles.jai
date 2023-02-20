#import "Random";

generate_particle_cloud :: (center : vec3, D : float, count : u32) -> Mesh_Raw_SOA {
	make_coord :: (center : vec3, D : float) -> vec3 {
		phi := random_get_within_range(0, 2 * PI);
		y := random_get_within_range(-1, 1);
		R := random_get_within_range(0, D); 

		rxz := sqrt(1 - y * y);
		return vec3.{sin(phi) * rxz, y, cos(phi) * rxz} * R;
	}

	mesh := Mesh_Raw_SOA.{
		points = NewArray(count, vec3),
		most_general = .P,
		gl_ready = false
	};
	for * mesh.points {
		<<it = make_coord(center, D);
	}
	return mesh;
}


SRC_PARTICLE_VERT :: #string GLSL
#version 430 core

layout (location = 0) in vec3 position;
// layout (location = 1) in vec3 color;
// layout (location = 1) in vec2 _tex_uv;

uniform mat4 u_transform;
out float _freq;

float rand(vec2 n) { 
	return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

void main() {
	gl_Position = u_transform * vec4(position, 1.);
	_freq = rand(vec2(rand(position.xy), position.z));
}
GLSL
SRC_PARTICLE_GEOM :: #string GLSL
#version 430 core

layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

uniform vec2 u_screen_size = vec2(1200, 800);
uniform float u_particle_size = 30;

in float _freq[];

out vec2 a_uv;
out float freq;

void add_point(vec4 p0, vec2 dxy, vec4 M) {
	gl_Position = p0 + vec4(dxy, 0, 0) * M; 
	a_uv = dxy;
	EmitVertex();
}

void main() {
	vec4 M = vec4(u_particle_size / (vec2(u_screen_size.x / u_screen_size.y, 1) * 1500), 1., 1.), p0 = gl_in[0].gl_Position;
#ifdef SCREEN_SCALE
	p0.xyz /= p0.w; p0.w = 1;
#else
	M.xyz *= 4;
#endif

	freq = _freq[0];

	add_point(p0, vec2(-1, -1), M);
	add_point(p0, vec2( 1, -1), M);
	add_point(p0, vec2(-1,  1), M);
	add_point(p0, vec2( 1,  1), M);

	EndPrimitive();
}
GLSL
SRC_PARTICLE_FRAG :: #string GLSL
#version 430 core

uniform sampler2D u_tex;
uniform vec2 u_screen_size = vec2(1200, 800);
uniform float u_time;

in vec2 a_uv;
in float freq;
out vec4 color;  

float z_near = .02, z_far  = 130;

float linearize_depth(float depth)  {
	float z = depth * 2 - 1; 
	return (2 * z_near * z_far) / (z_far + z_near - z * (z_far - z_near));	
}

void main() {
	float d0 = linearize_depth(texture(u_tex, (gl_FragCoord.xy) / u_screen_size).r);
	float d1 = linearize_depth(gl_FragCoord.z);

	float depth_factor = 1;//clamp((d0 - d1) / 0.01, 0, 1);
	float dist_factor = pow(max(1 - length(a_uv), 0), 2);
	float time_factor = 1;//sin((u_time + 10) * (1 + freq) * 2) * .5 + .5;

	float brightness = depth_factor * dist_factor * time_factor;

	color = vec4(vec3(.3, .8, .1), brightness);
}
GLSL