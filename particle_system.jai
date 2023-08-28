Particle_Sim :: struct {
	pos, vel : Vector3;
	timer : float;
	size : float;
	color : Vector3;
	repl : u32;
}
Particle_System :: struct {
	particles_max : u32;
	particles_alive : u32;

	vao, vbo : u32;
	
	shader_draw : Shader;
	shader_simulate : Shader;
	shader_emit : Shader;
	
	particles_counter : Atomic_Counter;
}
init :: (using particle_system : *Particle_System, _particles_max : u32, src_frag := GLSL_FRAG_PARTICLE) {
	particles_max = _particles_max;

	glGenVertexArrays(1, *vao);
	glGenBuffers(1, *vbo);
	glBindVertexArray(vao);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);

	glBufferData(GL_ARRAY_BUFFER, particles_max * size_of(Particle_Sim), null, GL_DYNAMIC_DRAW);

	particles_counter = Atomic_Counter.make();

	shader_draw = make_shader_vf(GLSL_VERT_PARTICLE, src_frag);
	shader_simulate = make_shader_c(GLSL_COMP_PARTICLE_SIMULATE, 16, 1, 1);
	shader_emit = make_shader_c(GLSL_COMP_PARTICLE_EMIT, 16, 1, 1);
}
deinit :: (using particle_system : *Particle_System) {
	clear(particles_counter);

	clear_shader(*shader_draw);
	clear_shader(*shader_simulate);
	clear_shader(*shader_emit);

	glDeleteVertexArrays(1, *vao);
	glDeleteBuffers(1, *vbo);
}
draw :: (using particle_system : Particle_System, mat_mvp : Matrix4, ratio : float) {
	use(shader_draw);
		set(*shader_draw, "ratio", ratio);
		set(*shader_draw, "mvp", mat_mvp);
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, vbo);

	glBindVertexArray(vao);
		glDrawArrays(GL_TRIANGLES, 0, xx (particles_alive * 6));
}
simulate :: (using particle_system : *Particle_System, delta_time : float) {
	particles_alive = get(particles_counter);
	
	use(*shader_simulate);
		set(*shader_simulate, "u_dt", delta_time);
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, particle_system.vbo);
		bind(particles_counter, 0);

	glDispatchCompute(xx particles_alive, 1, 1);
	glMemoryBarrier(GL_ALL_BARRIER_BITS);

	particles_alive = get(particles_counter);
}
emit :: (using particle_system : *Particle_System, point : Vector3, new_particles_count := 30, speed_factor := 1.,
	base_color := Vector3.{1, 0, 0}, base_variation := Vector3.{.1, 0, 0},
	aspect_color := Vector3.{1, 1, 1}, aspect_variation := Vector3.{}
) {
	use(shader_emit);
		set(*shader_emit, "u_random_state", __random_state);
		set(*shader_emit, "u_center", point);
		set(*shader_emit, "u_base_color", base_color);
		set(*shader_emit, "u_base_variation", base_variation);
		set(*shader_emit, "u_aspect_color", aspect_color);
		set(*shader_emit, "u_aspect_variation", aspect_variation);
		set(*shader_emit, "u_speed_factor", speed_factor);
		bind(particles_counter, 0);
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, vbo);

	__random_state += 1;

	glDispatchCompute(xx new_particles_count, 1, 1);
	glMemoryBarrier(GL_ALL_BARRIER_BITS);		
}

#scope_file
#import "GL";

Particle :: struct {
	lifetime : float;
	pos, velocity, acceleration : Vector3;
	dragg : float;
	base_color, aspect_color : Vector3;
	next : u32;
}

__random_state : s32;
GLSL_COMP_PARTICLE_EMIT :: #string GLSL
	#version 430

	struct Particle_Sim {
		float lifetime;

		vec3 pos;
		vec3 velocity;
		vec3 acceleration;
		float dragg;

		vec3 base_color;
		vec3 aspect_color;

		uint next;
	};
	layout(std430, binding = 0) buffer u_sim_particles {
		Particle_Sim sim_particles[];
	};
	layout (binding = 0) uniform atomic_uint u_alive_counter;

	uniform int u_random_state;
	uniform vec3 u_center;
	uniform float u_speed_factor;

	uniform vec3 u_base_color;
	uniform vec3 u_base_variation;

	uniform vec3 u_aspect_color;
	uniform vec3 u_aspect_variation;

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

	vec3 hsv2rgb(vec3 c) {
		vec4 K = vec4(1., 2. / 3., 1. / 3., 3.);
		return c.z * mix(K.xxx, clamp(abs(fract(c.x + K.xyz) * 6. - K.w) - K.x, 0, 1), c.y);
	}
	vec3 rgb2hsv(vec3 c) {
		float
			cMax = max(max(c.r, c.g), c.b),
			cMin = min(min(c.r, c.g), c.b),
			delta = cMax - cMin;
		vec3 hsv = vec3(0, 0, cMax);
		if(cMax > cMin){
			hsv.y = delta / cMax;
			if(c.r == cMax){
				hsv.x = (c.g - c.b) / delta;
			} else if(c.g == cMax){
				hsv.x = 2 + (c.b - c.r) / delta;
			} else {
				hsv.x = 4 + (c.r - c.g) / delta;
			}
			hsv.x = fract(hsv.x / 6);
		}
		return hsv;
	}

	vec3 gen_color(vec3 col, vec3 H, vec3 variation) {
		vec3 hsv = rgb2hsv(col) + (H - .5) * variation;
		hsv.x = mod(hsv.x, 1);
		return hsv2rgb(hsv);
	}

	Particle_Sim gen_particle(uint i) {
		float fi = float(i);
		vec3 H = hash32(vec2(fi, u_random_state));
		vec3 phi_y_r = vec3(H.x * 2 * PI, H.y * 2 - 1, (H.z * .3 + 1) * 3);
		vec3 speed = vec3(0, 3, 0) + .7 * phi_y_r.z * vec3(vec2(sin(phi_y_r.x), cos(phi_y_r.x)) * sqrt(1 - phi_y_r.y * phi_y_r.y),  phi_y_r.y);
		float timer = 2.5 + .5 * hash22(vec2(fi, u_random_state + 1)).x;

		vec3 var = hash32(vec2(fi, u_random_state + 2)) - .5;
	
		return Particle_Sim(
			timer,
			u_center,
			speed * u_speed_factor,
			vec3(0, -2, 0),
			2,
			gen_color(u_base_color.rgb, var, u_base_variation),
			gen_color(u_aspect_color.rgb, var, u_aspect_variation),
			0xFFFFFFFF
		);
	}

	void main() {
		uint particle_id = atomicCounterIncrement(u_alive_counter);
		sim_particles[particle_id] = gen_particle(particle_id);
	}
GLSL
GLSL_COMP_PARTICLE_SIMULATE :: #string GLSL
	#version 430

	struct Particle_Sim {
		float lifetime;
		vec3 pos;
		vec3 velocity;
		vec3 acceleration;
		float dragg;

		vec3 base_color;
		vec3 aspect_color;

		uint next;
	};
	layout(std430, binding = 0) buffer u_sim_particles {
		Particle_Sim sim_particles[];
	};
	layout (binding = 0) uniform atomic_uint u_alive_counter;

	uniform float u_dt;

	void main() {
		int particle_id = int(gl_GlobalInvocationID.x);
		uint alive_count = atomicCounter(u_alive_counter);

		if(particle_id < alive_count) {
			Particle_Sim P = sim_particles[particle_id];
			P.velocity.xyz += P.acceleration * u_dt;
			P.velocity.xyz *= (1 - P.dragg * u_dt);
			P.pos += P.velocity.xyz * u_dt;

			P.lifetime -= u_dt;
			if(P.lifetime < 0) {
				P.next = atomicCounterDecrement(u_alive_counter);
			}
			sim_particles[particle_id] = P;
		}
		memoryBarrier();
		alive_count = atomicCounter(u_alive_counter);

		if(particle_id < alive_count) {
			uint repl = particle_id;
			int MAX_ITERATIONS = 100;
			for(int i = 0; i < MAX_ITERATIONS; i++) {
				uint next = sim_particles[repl].next;
				if(next == 0xFFFFFFFF) break;
				repl = next;
			}
			sim_particles[particle_id] = sim_particles[repl];
		}
	}
GLSL
GLSL_VERT_PARTICLE :: #string GLSL
	#version 430

	uniform mat4 mvp;
	uniform float ratio = 1;
	const float size = .5;

	struct Particle_Sim {
		float lifetime;
		vec3 pos;
		vec3 velocity;
		vec3 acceleration;
		float dragg;

		vec3 base_color;
		vec3 aspect_color;

		uint next;
	};
	layout(std430, binding = 0) buffer u_sim_particles {
		Particle_Sim sim_particles[];
	};

	struct Particle_Visual {
		vec2 uv;
		vec3 base_color;
		vec3 aspect_color;
		float angle;
	};
	out Particle_Visual particle_visual;

	void main() {
		int id = gl_VertexID;
		int particle_id = id / 6;
		int offset_id = id % 6;

		vec2 offsets[6] = vec2[6](
			vec2(-1,-1),
			vec2( 1, 1),
			vec2(-1, 1),
			vec2(-1,-1),
			vec2( 1,-1),
			vec2( 1, 1)
		);
		Particle_Sim particle = sim_particles[particle_id]; 
		float time = particle.lifetime;
		float scale = time <= 0 ? 0 : 1 - 1 / (20 * time + 1);

		vec4 p = mvp * vec4(particle.pos, 1);
		vec2 offset = offsets[offset_id];

		particle_visual = Particle_Visual(
			offset,
			particle.base_color.rgb,
			particle.aspect_color.rgb,
			0
		);

		gl_Position = p + vec4(offset * vec2(ratio, 1), 0, 0) * size * scale;
	}
GLSL
GLSL_FRAG_PARTICLE :: #string GLSL
	#version 430

	struct Particle_Visual {
		vec2 uv;
		vec3 base_color;
		vec3 aspect_color;
		float angle;
	};
	in Particle_Visual particle_visual;
	out vec4 o_color;

	void main() {
		float r = length(particle_visual.uv);
		float theta = atan(particle_visual.uv.y, particle_visual.uv.x);
		float m = pow(sin(theta * 5) * .5 + .5, .5);

		o_color = vec4(
			mix(particle_visual.aspect_color, particle_visual.base_color, m),
			r > 1 ? 0 : pow(1 - r, 3)
		);
	}
GLSL