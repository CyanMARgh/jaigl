demo_5 :: () {
	width, height : s32 = 1920, 1080; 
	PARTICLES_MAX :u32: 20000;

	window := create_window(width, height, "advanced particles"); defer close_window(window);
	saved_window_info : Saved_Window_Info;	
	ok:, width, height = toggle_fullscreen(window, true, *saved_window_info);

	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera;

	particle_system : Particle_System; init(*particle_system, PARTICLES_MAX); defer deinit(*particle_system);
	emitter : Emitter; init(*emitter); defer deinit(*emitter);

	get_color :: () -> Vector3 { return hsv2rgb(.{random_get_within_range(0, 1), random_get_within_range(.7, 1.), 1}); }
	get_center :: () -> Vector3 { return Vector3.{random_get_within_range(-1, 1), random_get_within_range(-1, 2), random_get_within_range(-1, 1)} * 3; }

	for i: 0..0 spawn(*particle_system, *emitter, 3000, get_color(), get_center());

	//TODO macro for default loop
	time := current_time_monotonic();
	time_last_spawn := time;
	while !win_state.should_exit {
		// input
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		time_from_previous := to_float64_seconds(new_time - time_last_spawn);
		Input.update_window_events();
		move_camera(*camera, xx dt, win_state.pressed_keys);
		for Input.events_this_frame handle_event(*win_state, it);

		//spawn
		if time_from_previous > .5 {
			time_last_spawn = new_time;
			spawn(*particle_system, *emitter, 1000, get_color(), get_center());
		}

		// simulate
		simulate(*particle_system, xx dt);
		simp.clear_render_target(.0, .0, .0, 1);
		glClear(GL_DEPTH_BUFFER_BIT);
		draw(particle_system, camera, .{xx width, xx height});

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

#scope_file
Particle :: struct {
	pos : Vector3;
	size : float;
	color : Vector3;
}
Particle_Sim :: struct {
	pos, vel : Vector3;
	timer : float;
	size : float;
	color : Vector3;
	repl : u32;
}
Particle_System :: struct {
	max_particles : u32;
	particles_alive : u32;

	buffer_particles_sim : Shader_Storage;
	counter_alive : Atomic_Counter;
	mesh_particles : Mesh;

	shader_simulate : Shader;
	shader_pass : Shader;
	shader_draw : Shader;
}
init :: (using particle_system : *Particle_System, _max_particles : u32) {
	max_particles = _max_particles;
	mesh_particles = make_empty_mesh_no_ebo(max_particles, Particle);
	buffer_particles_sim = Shader_Storage.make(max_particles, size_of(Particle_Sim));
	counter_alive = Atomic_Counter.make();
	reset(counter_alive, 0);

	shader_simulate = make_shader_c(SRC_PARTICLE_SIMULATE_COMP, 16, 1, 1);
	shader_pass = make_shader_c(SRC_PARTICLE_TO_VBO_COMP, 8, 1, 1);
	shader_draw = make_shader_vf(SRC_PARTICLE_DRAW_VERT, SRC_PARTICLE_DRAW_FRAG);
}
deinit :: (using particle_system : *Particle_System) {
	clear_shader(*shader_draw);
	clear_shader(*shader_simulate);
	clear_shader(*shader_pass);

	clear(counter_alive);
	clear(buffer_particles_sim);
	clear_mesh(mesh_particles);
}
simulate :: (using particle_system : *Particle_System, dt : float) {
	use(shader_simulate);
		bind(buffer_particles_sim, 0);
		bind(counter_alive, 0);
		set(*shader_simulate, "u_dt", cast(float) dt);
	compute(shader_simulate, particles_alive, 1, 1);
	particles_alive = get(counter_alive);
}
draw :: (using particle_system : Particle_System, camera : Camera, screen_size : Vector2) {
	use(shader_pass);
		bind(buffer_particles_sim, 0);
		bind_vbo_as_storage(mesh_particles, 1);
		bind(counter_alive, 0);
	compute(shader_pass, particles_alive, 1, 1);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE);
	use(shader_draw);
		set(*shader_draw, "u_transform", get_transform(*camera, screen_size));
	draw(mesh_particles, GL_POINTS, particles_alive);
}
Emitter :: struct {
	shader_emit : Shader;
}
init :: (using emitter : *Emitter)  {
	shader_emit = make_shader_c(SRC_PARTICLE_EMIT_COMP, 8, 1, 1);
}
deinit :: (using emitter : *Emitter) {
	clear_shader(*shader_emit);
}
spawn :: (using particle_system : *Particle_System, using emitter : Emitter, amount : u32, color : Vector3, center : Vector3) {
	use(shader_emit);
		bind(buffer_particles_sim, 0);
		bind(counter_alive, 0);
		set(*shader_emit, "u_max_particles", max_particles);
		set(*shader_emit, "u_emit_counter", amount);
		set(*shader_emit, "u_color", color);
		set(*shader_emit, "u_center", center);
	compute(shader_emit, amount, 1, 1);
	particles_alive = get(counter_alive);
}

#import "Random";

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
