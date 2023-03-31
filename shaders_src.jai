SRC_VERT :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec2 a_uv;
	layout (location = 2) in vec3 a_norm;

	uniform mat4 u_transform_mv;
	uniform mat4 u_transform_p;

	out struct Vert_Out {
		vec3 pos;
		vec2 uv;
		vec3 norm;
	} vert_out;

	void main() {
		vert_out.pos = a_pos;
		vert_out.uv = a_uv;
		vert_out.norm = a_norm;
		gl_Position = u_transform_p * (u_transform_mv * vec4(a_pos, 1));
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


SRC_SCREEN_VERT :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec2 a_uv;

	out struct Vert_Out {
		vec2 uv;
	} vert_out;

	void main() {
		vert_out.uv = a_uv;
		gl_Position = vec4(a_pos, 1);
	}
GLSL
SRC_SCREEN_FRAG :: #string GLSL
	#version 430 core

	layout(binding = 0) uniform sampler2D u_color;
	layout(binding = 1) uniform sampler2D u_depth;

	in struct Vert_Out {
		vec2 uv;
	} vert_out;

	out vec4 o_color;

	float z_near = .01, z_far  = 100;
	float linearize_depth(float depth)  {
		float z = depth * 2 - 1; 
		return (2 * z_near * z_far) / (z_far + z_near - z * (z_far - z_near));	
	}

	vec2 flip(vec2 uv) {
		// return vec2(uv.x, 1 - uv.y);
		return uv;
	}

	void main() {	
		// o_color = texture(u_color, vert_out.uv) * .5 + vec4(vert_out.uv, 0, 1) * .5;
		// o_color = texture(u_depth, vert_out.uv) * .5 + vec4(vert_out.uv, 0, 1) * .5;
		float d = texture(u_depth, vert_out.uv).x;
		vec3 col =  texture(u_color, flip(vert_out.uv)).xyz;
		o_color = vec4(gl_FragCoord.x < 600 ? vec3(linearize_depth(d)) : col, 1);
		// o_color = vec4(vert_out.uv, 0, 1);
	}
GLSL


SRC_PENDULUM_SCREEN_FRAG :: #string GLSL
	#version 430 core

	uniform sampler2D u_screen;

	in struct Vert_Out {
		vec2 uv;
	} vert_out;

	out vec4 o_color;

	const float PI = 3.1415926538;

	vec3 twilight_shifted(float t) {
		const vec3 c0 = vec3(0.120488, 0.047735, 0.106111);
		const vec3 c1 = vec3(5.175161, 0.597944, 7.333840);
		const vec3 c2 = vec3(-47.426009, -0.862094, -49.143485);
		const vec3 c3 = vec3(197.225325, 47.538667, 194.773468);
		const vec3 c4 = vec3(-361.218441, -146.888121, -389.642741);
		const vec3 c5 = vec3(298.941929, 151.947507, 359.860766);
		const vec3 c6 = vec3(-92.697067, -52.312119, -123.143476);
		return c0 + t * (c1 + t * (c2 + t * (c3 + t * (c4 + t * (c5 + t * c6)))));
	}
	vec3 pal(in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d) {
	    return a + b*cos( 6.28318*(c*t+d) );
	}


	vec3 palette(vec2 p) {
		float t = atan(p.x, p.y) / (PI * 2) + .5;
		// return twilight_shifted(t);
		return pal(t, vec3(.5, .5, .5), vec3(.5, .5, .5), vec3(1., 1., 1.), vec3(0., .1, .2));
	}

	void main() {
		o_color = vec4(palette(texture(u_screen, vert_out.uv).xy), 1);
		// o_color = vec4(vert_out.uv, 0, 1);
	}
GLSL
SRC_PENDULUM_INIT_COMP :: #string GLSL
	#version 430 core
	// layout(local_size_x = 8, local_size_y = 4, local_size_z = 1) in;
	layout(rgba32f, binding = 0) uniform image2D states;

	uniform float u_time;

	void set(ivec2 pixel_coords, vec4 state) {
		imageStore(states, pixel_coords, state);
	}

	void main() {
		ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
		ivec2 dims = imageSize(states);

		vec2 uv = (vec2(pixel_coords) / vec2(dims) - .5) * 2;
		uv.x *= float(dims.x) / float(dims.y);

		set(pixel_coords, vec4(uv, 0, 0));
	}
GLSL
SRC_PENDULUM_ITERATE_COMP :: #string GLSL
	#version 430 core
	// layout(local_size_x = 8, local_size_y = 4, local_size_z = 1) in;
	layout(rgba32f, binding = 0) uniform image2D states;

	uniform float u_time;
	uniform float u_dtime;

	const float PI = 3.1415926538;

	vec4 get(ivec2 pixel_coords) {
		return imageLoad(states, pixel_coords);
	}
	void set(ivec2 pixel_coords, vec4 state) {
		imageStore(states, pixel_coords, state);
	}

	const int NC = 5;
	struct Model_Params {
		float C, R, d, w, r;
		// vec2 nodes[NC];
	};
	// const
	Model_Params model_params;// = Model_Params(.2, .2, .1, 10);

	vec2 rotate(vec2 p, float t) {
		float c = cos(t), s = sin(t);
		return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	}

	vec4 get_derivative(vec4 p, float t) {
		vec2 pos = p.xy, vel = p.zw;
		vec2 force = -(model_params.C * pos + model_params.R * vel);
		float dd = model_params.d * model_params.d;
		for(int i = 0; i < NC; i++) {
			vec2 node = rotate(vec2(model_params.r, 0), 2 * PI * float(i) / NC + t * model_params.w);
			vec2 dp = node - pos;
			force += (mat2x2(1, 0, 0, 1) * dp) / pow(dot(dp, dp) + dd, 1.5);
		}
		return vec4(vel.xy, force.xy);
	}

	vec4 iterate(vec4 s, float t, float h) {
		vec4 K1 = get_derivative(s, t);
		return s + K1 * h;
	}
	vec4 iterate_4(vec4 s, float t, float h) {
		vec4 K1 = get_derivative(s, t);
		vec4 K2 = get_derivative(s + K1 * h / 2, t + h / 2);
		vec4 K3 = get_derivative(s + K2 * h / 2, t + h / 2);
		vec4 K4 = get_derivative(s + K3 * h, t + h);
		return s + (h / 6) * (K1 + 2 * K2 + 2 * K3 + K4);
	}

	vec4 sub_iterate_4(int N, vec4 s, float t0, float dt) {
		for(int i = 0; i < N; i++) {
			s = iterate_4(s, t0 + dt * float(i) / float(N), dt / float(N));
		}
		return s;
	} 
	void main() {
		ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
		ivec2 dims = imageSize(states);

		float M = 6;

		float x = float(pixel_coords.x) / float(dims.x);
		float w = exp(mix(log(995), log(1000), x));

		model_params = Model_Params(.2, .2, .1, w, 1);	

		// const Model_Params model_params = Model_Params(.2, .2, .1, 10);

		vec4 s = get(pixel_coords);
		set(pixel_coords, 
			// x < .5 ?
			// iterate(s, u_time / M, u_dtime / M) :
			sub_iterate_4(10, s, u_time / M, u_dtime / M) 
			//:
			// iterate_4(s, u_time / M, u_dtime / M)
		);
	}
GLSL

SRC_OIT_TO_NODES_FRAG :: #string GLSL 
	#version 430 core

	struct Node {
		vec4 color;
		uint prev;
		float depth;
	};

	layout (r32ui, binding = 0) uniform uimage2D u_heads;
	layout (binding = 0, std430) buffer u_lists {
		Node nodes[];
	};
	layout (binding = 0) uniform atomic_uint pixel_counter;
	const vec2 u_screen_size = vec2(1200, 800);
	uniform uint max_nodes = uint(u_screen_size.x) * uint(u_screen_size.y) * 5;
	uniform float u_time = 0;

	in struct Vert_Out {
		vec3 pos;
		vec2 uv;
		vec3 norm;
	} vert_out;

	void main() {
		float alpha = sin(dot(vert_out.pos, vec3(3, 1, 2)) * .5 + u_time) * .5 + .5;
		alpha = pow(alpha, 2);
		// float alpha = .6;

		vec4 color = vec4(normalize(vert_out.norm) * .5 + .5, alpha);
		ivec2 coord = ivec2(gl_FragCoord.xy);

		uint node_id = atomicCounterIncrement(pixel_counter);
		if(node_id < max_nodes) {
			uint prev = imageAtomicExchange(u_heads, coord, node_id);
			nodes[node_id] = Node(color, prev, gl_FragCoord.z);
		}
	}
GLSL
SRC_OIT_FROM_NODES_FRAG :: #string GLSL
	#version 430 core

	layout (r32ui, binding = 0) uniform uimage2D u_heads;
	struct Node {
		vec4 color;
		uint prev;
		float depth;
	};
	layout (std430, binding = 0) buffer u_lists {
		Node nodes[];
	};
	const vec2 u_screen_size = vec2(1200, 800);

	out vec4 o_color;

	// houndstooth
	// vec4 get_color() {
	// 	vec2 uv = fract(gl_FragCoord.xy / 100);
	// 	float sharpness = 100;
	// 	vec2 mask = clamp((uv - .5) * sharpness, 0., 1.);
	// 	float color = clamp((abs((fract(abs(uv.x-uv.y)*2.+.25)-.5)*2.)-.5)*sharpness/5.,0.,1.);
	// 	color = max(color, min(mask.x, mask.y)) * max(mask.x, mask.y);
	// 	color = .5 + color * .5;

	// 	return vec4(color, color, color, 1);
	// }

	// paper
	vec2 hash22(vec2 p) {
	    p = p * mat2(127.1, 311.7, 269.5 ,183.3);
		p = -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
		return sin(p * 6.283);
	}
	float perlin_level(vec2 p) {
		vec2 pi = floor(p);
	    vec2 pf = p - pi;
	    vec2 w = pf;
	    
	    vec2
	        d00 = hash22(pi + vec2(0., 0.)),
	        d01 = hash22(pi + vec2(0., 1.)),
	        d10 = hash22(pi + vec2(1., 0.)),
	        d11 = hash22(pi + vec2(1., 1.));

	    float
	        f00 = dot(d00, pf - vec2(0., 0.)),
	        f01 = dot(d01, pf - vec2(0., 1.)),
	        f10 = dot(d10, pf - vec2(1., 0.)),
	        f11 = dot(d11, pf - vec2(1., 1.));
	    
	    float
	        m00 = f00 * (1. - w.x) * (1. - w.y),
	        m01 = f01 * (1. - w.x) *        w.y,
	        m10 = f10 *        w.x * (1. - w.y),
	        m11 = f11 *        w.x *        w.y;
	    
	    return m00 + m01 + m10 + m11;   
	}
	vec3 perlin_level_full(vec2 p) {
		vec2 pi = floor(p);
	    vec2 pf = p - pi;
	    vec2 w = pf * pf * (3. - 2. * pf);
	        
	    vec2
	        d00 = hash22(pi + vec2(0., 0.)),
	        d01 = hash22(pi + vec2(0., 1.)),
	        d10 = hash22(pi + vec2(1., 0.)),
	        d11 = hash22(pi + vec2(1., 1.));

	    float
	        f00 = dot(d00, pf - vec2(0., 0.)), // * (1-x) * (1-y)
	        f01 = dot(d01, pf - vec2(0., 1.)), // * x * (1-y)
	        f10 = dot(d10, pf - vec2(1., 0.)), // * (1 -x) * y
	        f11 = dot(d11, pf - vec2(1., 1.)); // * x * y
	    
	    vec2 gw = 6. * (pf - pf * pf); 
	    vec2
	        g00 = d00 * (1. - w.x) * (1. - w.y) + f00 * vec2((w.y - 1.), (w.x - 1.)) * gw,
	        g01 = d01 * (1. - w.x) * w.y        + f01 * vec2(-w.y, (1. - w.x)) * gw,
	        g10 = d10 * w.x * (1. - w.y)        + f10 * vec2((1. - w.y),  -w.x) * gw,
	        g11 = d11 * w.x * w.y               + f11 * vec2(w.y, w.x) * gw;
	        
	    float h = 
	        f00 * (1. - w.x) * (1. - w.y) +
	        f01 * (1. - w.x) * w.y +
	        f10 * w.x * (1. - w.y) + 
	        f11 * w.x * w.y;
	    vec2 gh = g00 + g01 + g10 + g11;
	    return vec3(h, gh); 
	}
	float perlin(vec2 p) {
		float a = 1., r = 0., s=0.;    
	    for(int i = 0; i < 8; i++) {
	      r += a * perlin_level(p);
	      s += a; p *= 2.; a *= .5;
	    }
	    return r / s;
	}
	vec3 perlin_full(vec2 p, int I) {
	    vec3 r = vec3(0.);
	    float a = 1., s = 0.;
	    for(int i = 0; i < I; i++) {
	      r += perlin_level_full(p) * vec3(a, 1., 1.);
	      s += a; p *= 2.; a *= .5;
	    }
	    r /= s;    
	    return vec3(r.x * .5 + .5, .5 * r.yz);
	}
	vec4 get_color() {
		vec2 uv = gl_FragCoord.xy / vec2(u_screen_size.x, u_screen_size.y) * mat2(1., 0., 0., 1.) + 10.;    

		uv *= 3.;    
		vec2 offset = vec2(.2);
		vec3 p = perlin_full(uv, 7);
		vec3 color_paper = vec3(mix(vec3(0.0, 0.0, -.3), vec3(1.), dot(p.xz, offset) * .1 + .9));

		return vec4(color_paper, 1);
	}

	void main() {
		const uint MAX_FRAGMENTS = 75;
		Node frags[MAX_FRAGMENTS];
		uint count = 0, n = imageLoad(u_heads, ivec2(gl_FragCoord.xy)).r;

	    while (n != 0xFFFFFFFF && count < MAX_FRAGMENTS) {
			frags[count] = nodes[n];
			n = frags[count].prev;
	        count++;
	    }

	    for (uint i = 1; i < count; i++) {
			Node to_insert = frags[i];
			uint j = i;

			while(j > 0 && to_insert.depth > frags[j-1].depth) {
				frags[j] = frags[j-1];
				j--;
			}
			frags[j] = to_insert;
	    }
		vec4 color = get_color();// vec4(1, 1, 0, 1);

		for (uint i = 0; i < count; i++) {    	
			color = mix(color, frags[i].color, frags[i].color.a);
		}
		o_color = vec4(color.rgb, 1);
	}
GLSL
SRC_OIT_CLEAR_COMP :: #string GLSL
	#version 430 core
	// layout(local_size_x = 8, local_size_y = 4, local_size_z = 1) in;
	layout(r32ui, binding = 0) uniform uimage2D u_screen;

	void main() {
		ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

		imageStore(u_screen, pixel_coords, ivec4(0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF));
	}
GLSL

SRC_PARTICLE_DRAW_VERT :: #string GLSL
	#version 430 core

	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in float a_size;
	layout (location = 2) in vec3 a_col;

	uniform mat4 u_transform;

	out struct Vert_Out {
		float size;
		vec3 col;
	} vert_out;

	void main() {
		gl_Position = u_transform * vec4(a_pos, 1.);
		vert_out.col = a_pos;
		vert_out.size = a_size;
		vert_out.col = /*vec3(0, 1, 0);*/a_col;
	}
GLSL
SRC_PARTICLE_DRAW_GEOM :: #string GLSL
	#version 430 core

	layout (points) in;
	layout (triangle_strip, max_vertices = 4) out;

	// TODO
	// uniform vec2 u_screen_size;
	// uniform float u_particle_size = 60;

	const vec2 u_screen_size = vec2(1200, 800);
	const float u_particle_size = 60;

	in struct Vert_Out {
		float size;
		vec3 col;
	} vert_out[];

	out struct Geom_Out {
		vec3 col;
		vec2 uv;
	} geom_out;

	void add_point(vec4 p0, vec2 dxy, vec4 M) {
		gl_Position = p0 + vec4(dxy, 0, 0) * M; 
		geom_out.uv = dxy;
		EmitVertex();
	}

	void main() {
		vec4 M = vert_out[0].size * vec4(u_particle_size / (vec2(u_screen_size.x / u_screen_size.y, 1) * 1500), 1., 1.), p0 = gl_in[0].gl_Position;
	#ifdef SCREEN_SCALE
		p0.xyz /= p0.w; p0.w = 1;
	#else
		M.xyz *= 4;
	#endif

		geom_out.col = vert_out[0].col;

		if(vert_out[0].size > 0) {
			add_point(p0, vec2(-1, -1), M);
			add_point(p0, vec2( 1, -1), M);
			add_point(p0, vec2(-1,  1), M);
			add_point(p0, vec2( 1,  1), M);

			EndPrimitive();
		}
	}
GLSL
SRC_PARTICLE_DRAW_FRAG :: #string GLSL
	#version 430 core

	// uniform sampler2D u_tex;
	// uniform vec2 u_screen_size;
	// uniform float u_time;

	const vec2 u_screen_size = vec2(1200, 800);

	in struct Geom_Out {
		vec3 col;
		vec2 uv;
	} geom_out;

	out vec4 color;  

	// float z_near = .02, z_far  = 130;

	// float linearize_depth(float depth)  {
	// 	float z = depth * 2 - 1; 
	// 	return (2 * z_near * z_far) / (z_far + z_near - z * (z_far - z_near));	
	// }

	void main() {
		// float d0 = linearize_depth(texture(u_tex, (gl_FragCoord.xy) / u_screen_size).r);
		// float d1 = linearize_depth(gl_FragCoord.z);

		float depth_factor = 1;//clamp((d0 - d1) / 0.01, 0, 1);
		float l = length(geom_out.uv);
		float dist_factor = pow(clamp(1 - l, 0, 1), 2); //pow(max(1 - length(a_uv), 0), 2);
		float time_factor = 1;// sin((u_time + 10) * (1 + freq) * 2) * .5 + .5;

		float brightness = depth_factor * dist_factor * time_factor;

		color = vec4(geom_out.col, brightness);
	}
GLSL

SRC_PARTICLE_GEN_COMP :: #string GLSL 
	#version 430 core
	// layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

	struct Vec3 { float x, y, z };

	struct Particle {
		Vec3 pos;
	};
	Vec3 to_Vec3(vec3 v) {
		return Vec3(v.x, v.y, v.z);
	}

	layout(std430, binding = 0) buffer u_vbo_particles {
	    Particle particles[];
	};

	uniform float u_time;

	vec2 hash22(vec2 p) {
		p = p * mat2(127.1, 311.7, 269.5 ,183.3);
		p = -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
		return sin(p * 6.283);
	}

	vec3 get_coord(float x) {
		return vec3(hash22(vec2(x, 0)), hash22(vec2(x, 1)).x);
	}

	void main() {
		ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

		vec3 particle_coord = get_coord(gl_GlobalInvocationID.x);

		particles[pixel_coords.x] = Particle(to_Vec3(particle_coord));
	}
GLSL

SRC_PARTICLE_INIT_COMP :: #string GLSL
	#version 430 core
	// layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

	struct Vec3 { float x, y, z; };
	Vec3 to_Vec3(vec3 v) { return Vec3(v.x, v.y, v.z); }
	vec3 from_Vec3(Vec3 v) { return vec3(v.x, v.y, v.z); }

	struct Particle_Sim {
		Vec3 pos, vel;
		float timer;
		float size;
		Vec3 color;
		uint next;
	};

	layout(std430, binding = 0) buffer u_sim_particles {
		Particle_Sim sim_particles[];
	};
	layout (binding = 0) uniform atomic_uint u_alive_counter;

	vec2 hash22(vec2 p) {
		p = p * mat2(127.1, 311.7, 269.5 ,183.3);
		p = -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
		return sin(p * 6.283);
	}

	void main() {
		ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
		uint alive_current = atomicCounter(u_alive_counter);

		if(pixel_coords.x < alive_current) {
			float x = float(pixel_coords.x);
			vec3 pos = vec3(hash22(vec2(x, 0)), hash22(vec2(x, 1)).x);
			vec3 vel = vec3(hash22(vec2(x, 2)), hash22(vec2(x, 3)).x);
			float timer = 5 * (2 + hash22(vec2(x, 4)).x);
			float size = .5 * (1.5 + hash22(vec2(x, 5)).x);
			vec3 col = vec3(hash22(vec2(x, 6)), hash22(vec2(x, 7)).x);
			col += 1.2; col /= max(max(col.x, col.y), col.z);

			sim_particles[pixel_coords.x] = Particle_Sim(to_Vec3(pos), to_Vec3(vel), timer, size, to_Vec3(col), 0xFFFFFFFF);			
		}
	}
GLSL
SRC_PARTICLE_TO_VBO_COMP :: #string GLSL
	#version 430 core
	// layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

	struct Vec3 { float x, y, z; };
	Vec3 to_Vec3(vec3 v) { return Vec3(v.x, v.y, v.z); }
	vec3 from_Vec3(Vec3 v) { return vec3(v.x, v.y, v.z); }

	struct Particle_Sim {
		Vec3 pos, vel;
		float timer;
		float size;
		Vec3 color;
		uint next;
	};
	struct Particle {
		Vec3 pos;
		float size;
		Vec3 color;
	};

	layout(std430, binding = 0) buffer u_sim_particles {
		Particle_Sim particles_sim[];
	};
	layout(std430, binding = 1) buffer u_vbo_particles {
		Particle particles[];
	};
	layout (binding = 0) uniform atomic_uint u_alive_counter;

	vec2 hash22(vec2 p) {
		p = p * mat2(127.1, 311.7, 269.5 ,183.3);
		p = -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
		return sin(p * 6.283);
	}

	void main() {
		ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);
		uint alive_current = atomicCounter(u_alive_counter);

		if(pixel_coords.x < alive_current) {
			Particle_Sim P = particles_sim[pixel_coords.x];

			float scale = P.timer > 0 ? 2 * (1 - 1 / (P.timer / 10 + 1)) : -.5;

			particles[pixel_coords.x] = Particle(P.pos, P.size * scale, P.color);			
		}

		// particles[pixel_coords.x] = Particle(Vec3(0, 0, 0), 1, Vec3(1, 0, 0));
	}
GLSL
SRC_PARTICLE_SIMULATE_COMP :: #string GLSL
	#version 430 core
	// layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

	struct Vec3 { float x, y, z; };
	Vec3 to_Vec3(vec3 v) { return Vec3(v.x, v.y, v.z); }
	vec3 from_Vec3(Vec3 v) { return vec3(v.x, v.y, v.z); }

	struct Particle_Sim {
		Vec3 pos, vel;
		float timer;
		float size;
		Vec3 color;
		uint next;
	};

	layout(std430, binding = 0) buffer u_sim_particles {
		Particle_Sim sim_particles[];
	};
	layout (binding = 0) uniform atomic_uint u_alive_counter;
	uniform float u_dt;

	vec2 hash22(vec2 p) {
		p = p * mat2(127.1, 311.7, 269.5 ,183.3);
		p = -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
		return sin(p * 6.283);
	}

	void main() {
		ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

		uint alive_current = atomicCounter(u_alive_counter);
		memoryBarrier();

		if(pixel_coords.x < alive_current) {
			float x = float(pixel_coords.x);
			Particle_Sim P = sim_particles[pixel_coords.x];
			vec3 pos = from_Vec3(P.pos);
			vec3 vel = from_Vec3(P.vel);

			if(P.timer >= 0) {
				float alpha = 1, beta = 2, gamma = 1.;
				float r = length(pos);

				vec3 force_friction = -vel * beta;
				vec3 force_gravity = vec3(0, -3, 0);
				vec3 force = force_friction + force_gravity;
				// vec3 force = pos * (alpha / (r * r * r + .01) - gamma) - vel * beta;

				pos += vel * u_dt;
				vel += force * u_dt;

				P.pos = to_Vec3(pos);
				P.vel = to_Vec3(vel);

				P.timer -= u_dt;
				if(P.timer < 0) {
					P.next = atomicCounterDecrement(u_alive_counter);
				}
				sim_particles[pixel_coords.x] = P;
			}
		}
		memoryBarrier();
		alive_current = atomicCounter(u_alive_counter);

		if(pixel_coords.x < alive_current) {
			uint repl = pixel_coords.x;
			int MAX_ITERATIONS = 100;
			for(int i = 0; i < MAX_ITERATIONS; i++) {
				uint next = sim_particles[repl].next;
				if(next == 0xFFFFFFFF) break;
				repl = next;
			}
			sim_particles[pixel_coords.x] = sim_particles[repl];
		}
	}
GLSL
SRC_PARTICLE_EMIT_COMP :: #string GLSL
	#version 430 core
	// layout(local_size_x = 8, local_size_y = 1, local_size_z = 1) in;

	struct Vec3 { float x, y, z; };
	Vec3 to_Vec3(vec3 v) { return Vec3(v.x, v.y, v.z); }
	vec3 from_Vec3(Vec3 v) { return vec3(v.x, v.y, v.z); }

	struct Particle_Sim {
		Vec3 pos, vel;
		float timer;
		float size;
		Vec3 color;
		uint next;
	};

	layout(std430, binding = 0) buffer u_sim_particles {
		Particle_Sim sim_particles[];
	};
	layout (binding = 0) uniform atomic_uint u_alive_counter;
	uniform uint u_max_particles;

	uniform uint u_emit_counter;
	uniform vec3 u_color;
	uniform vec3 u_center;

	vec2 hash22(vec2 p) {
		p = p * mat2(127.1, 311.7, 269.5 ,183.3);
		p = -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
		return sin(p * 6.283);
	}
	const float PI = 3.14159265;
	vec3 hash32(vec2 p) {
		vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
		p3 += dot(p3, p3.yxz+33.33);
		return fract((p3.xxy+p3.yzz)*p3.zyx);
	}


	Particle_Sim gen_particle(uint i) {
		float x = float(i);
		vec3 center = vec3(0, 0, 0);

		vec3 pos = u_center;
		vec3 phi_y_r = hash32(vec2(x, 0));
		phi_y_r = vec3(phi_y_r.x * 2 * PI, phi_y_r.y * 2 - 1, (phi_y_r.z * .3 + 1) * 4);

		vec3 vel = phi_y_r.z * vec3(vec2(sin(phi_y_r.x), cos(phi_y_r.x)) * sqrt(1 - phi_y_r.y * phi_y_r.y),  phi_y_r.y);

		float timer = 2 + .2 * hash22(vec2(x, 1)).x;
		float size = 3 * (1.5 + hash22(vec2(x, 2)).x);

		vec3 col;
		#ifdef JUSTRED
			col = vec3(1, .2, .1);
		#else
			col = clamp(u_color + hash32(vec2(x, 3)) * .2, vec3(0), vec3(1));
		#endif

		return Particle_Sim(to_Vec3(pos), to_Vec3(vel), timer, size, to_Vec3(col), 0xFFFFFFFF);
	}

	void main() {
		ivec2 pixel_coords = ivec2(gl_GlobalInvocationID.xy);

		uint id = atomicCounterIncrement(u_alive_counter);
		sim_particles[id] = gen_particle(id);
	}
GLSL

SRC_CHUNK_TO_VBO_COMP :: #string GLSL
	#version 430 core

	struct Vec3 { float x, y, z; };
	Vec3 to_Vec3(vec3 v) { return Vec3(v.x, v.y, v.z); }
	vec3 from_Vec3(Vec3 v) { return vec3(v.x, v.y, v.z); }
	struct Vec4 { float x, y, z, w; };
	Vec4 to_Vec4(vec4 v) { return Vec4(v.x, v.y, v.z, v.w); }
	vec4 from_Vec4(Vec4 v) { return vec4(v.x, v.y, v.z, v.w); }
	struct Ivec4 { int x, y, z, w; };
	Ivec4 to_Ivec4(ivec4 v) { return Ivec4(v.x, v.y, v.z, v.w); }
	ivec4 from_Ivec4(Ivec4 v) { return ivec4(v.x, v.y, v.z, v.w); }
	struct Ivec3 { int x, y, z; };
	Ivec3 to_Ivec3(ivec3 v) { return Ivec3(v.x, v.y, v.z); }
	ivec3 from_Ivec3(Ivec3 v) { return ivec3(v.x, v.y, v.z); }

	struct Block {
		uint type;
	};
	struct Face {
		Vec3 pos;
		Vec3 norm;
		Vec3 col;
		int extra;
	};

	layout(std430, binding = 0) buffer u_virtual_chunk {
		Block blocks[];
	};
	layout(std430, binding = 1) buffer u_visual_chunk {
		Face faces[];
	};
	layout (binding = 0) uniform atomic_uint u_face_counter;

	vec3 hash33(vec3 p3) {
		p3 = fract(p3 * vec3(.1031, .1030, .0973));
		p3 += dot(p3, p3.yxz + 33.33);
		return fract((p3.xxy + p3.yxx) * p3.zyx);
	}
	const uint CHUNK_SIZE = 16;
	Block at(ivec3 p) {
		if(p.x < 0 || p.y < 0 || p.z < 0 || p.x > CHUNK_SIZE || p.y > CHUNK_SIZE || p.z > CHUNK_SIZE) {
			return Block(0);
		}
		return blocks[CHUNK_SIZE * CHUNK_SIZE * p.z + CHUNK_SIZE * p.y + p.x];
	}
	vec3 get_color(ivec3 p) {
		vec3 col = hash33(vec3(p)) * .4 + .6;
		return col / max(col.x, max(col.y, col.z));
	}
	void make_face(ivec3 p0, ivec3 dp) {
		uint id = atomicCounterIncrement(u_face_counter);
		faces[id] = Face(
			to_Vec3(vec3(p0)),
			to_Vec3(vec3(dp)),
			to_Vec3(get_color(p0)),
			(p0.x + p0.y + p0.z) % 2
		);
	}
	void try_make_face(ivec3 p0, ivec3 dp) {
		Block b0 = at(p0), b1 = at(p0 + dp);
		if(b0.type != 0 && b1.type == 0) {
			make_face(p0, dp);
		}
	}

	void main() {
		ivec3 p0 = ivec3(gl_GlobalInvocationID.xyz);

		if(p0.x < CHUNK_SIZE && p0.y < CHUNK_SIZE && p0.z < CHUNK_SIZE) {
			try_make_face(p0, ivec3( 1,  0,  0));
			try_make_face(p0, ivec3(-1,  0,  0));
			try_make_face(p0, ivec3( 0,  1,  0));
			try_make_face(p0, ivec3( 0, -1,  0));
			try_make_face(p0, ivec3( 0,  0,  1));
			try_make_face(p0, ivec3( 0,  0, -1));
		}
	}
GLSL

SRC_BLOCK_VERT :: #string GLSL
	#version 430 core

	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec3 a_norm;
	layout (location = 2) in vec3 a_col;
	layout (location = 3) in int a_extra;

	uniform mat4 u_transform_p;
	uniform mat4 u_transform_mv;

	out struct Vert_Out {
		vec3 norm;
		vec3 col;
	} vert_out;
	
	void main() {
		gl_Position = vec4(a_pos, 1);
		vert_out.norm = a_norm;
		vert_out.col = a_extra == 1 ? a_col : vec3(0);
	}
GLSL
SRC_BLOCK_GEOM :: #string GLSL
	#version 430 core

	layout (points) in;
	layout (triangle_strip, max_vertices = 4) out;

	uniform mat4 u_transform_p;
	uniform mat4 u_transform_mv;

	const vec2 u_screen_size = vec2(1200, 800);
	const float u_particle_size = 60;

	in struct Vert_Out {
		vec3 norm;
		vec3 col;
	} vert_out[];

	out struct Geom_Out {
		vec3 col;
		vec2 uv;
	} geom_out;

	void add_point(vec4 p0, vec3 dp, vec2 uv) {
		gl_Position = u_transform_p * u_transform_mv * (p0 + vec4(dp * .5, 0)); 
		geom_out.uv = uv;
		EmitVertex();
	}

	void main() {
		vec3 n0 = vert_out[0].norm;
		vec4 p0 = gl_in[0].gl_Position + vec4(n0 * .5, 0);
		vec3 n1 = n0.yzx;
		vec3 n2 = -cross(n0, n1);

		geom_out.col = vert_out[0].col;

		add_point(p0,   n1 + n2, vec2(1, 1));
		add_point(p0,   n1 - n2, vec2(1, 0));
		add_point(p0, - n1 + n2, vec2(0, 1));
		add_point(p0, - n1 - n2, vec2(0, 0));

		EndPrimitive();
	}
GLSL
SRC_BLOCK_FRAG :: #string GLSL
	#version 430 core

	in struct Geom_Out {
		vec3 col;
		vec2 uv;
	} geom_out;

	// in struct Vert_Out {
	// 	vec3 norm;
	// 	vec3 col;
	// } vert_out;

	out vec4 o_color;
	void main() {
		// o_color = vec4(geom_out.uv, 0, 1);
		o_color = vec4(geom_out.col, 1);
		// o_color = vec4(1, 1, 0, 1);
		// o_color = vec4(vert_out.col, 1);
	}
GLSL

SRC_CHUNK_FILL_COMP :: #string GLSL
	#version 430 core

	struct Block {
		uint type;
	};

	layout(std430, binding = 0) buffer u_virtual_chunk {
		Block blocks[];
	};

	const uint CHUNK_SIZE = 16;
	void set_block(ivec3 p, Block block) {
		if(p.x < 0 || p.y < 0 || p.z < 0 || p.x > CHUNK_SIZE || p.y > CHUNK_SIZE || p.z > CHUNK_SIZE) {
			return;
		}
		blocks[CHUNK_SIZE * CHUNK_SIZE * p.z + CHUNK_SIZE * p.y + p.x] = block;
	}
	vec3 hash33(vec3 p3) {
		p3 = fract(p3 * vec3(.1031, .1030, .0973));
		p3 += dot(p3, p3.yxz + 33.33);
		return fract((p3.xxy + p3.yxx) * p3.zyx);
	}


	void main() {
		ivec3 p0 = ivec3(gl_GlobalInvocationID.xyz);

		if(p0.x < CHUNK_SIZE && p0.y < CHUNK_SIZE && p0.z < CHUNK_SIZE) {
			// float h = hash33(vec3(p0)).x;
			vec3 r = (vec3(p0) / 15) * 2 - 1;
			float h = length(r) - .8;

			set_block(p0, h > 0 ? Block(0) : Block(1));
		}
	}
GLSL


SRC_INT_TEST_VERT :: #string GLSL
	#version 430 core

	layout (location = 0) in int a_x;

	void main() {
		gl_Position = vec4(float(a_x) / 5, 0, 0, 1);
	}
GLSL
SRC_INT_TEST_FRAG :: #string GLSL
	#version 430 core

	out vec4 o_color;
	void main() {
		o_color = vec4(1, 1, 0, 1);
	}
GLSL