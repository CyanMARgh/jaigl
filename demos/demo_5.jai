demo_5 :: () {
	window := create_window(1200, 800, "voxels"); defer close_window(window);
	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera = .{position = .{7.5, 7.5, 20}};

	ivec4 :: struct {
		x, y, z, w : s32;
	}
	ivec3 :: struct {
		x, y, z : s32;
	}
	Voxel_Face :: struct {
		pos : Vector3;
		norm : Vector3; // TODO -> u32
		col : Vector3;
		extra : s32;
	}
	print("S = %\n", size_of(Voxel_Face));
	Block :: struct {
		type : u32;
	}

	FACES_MAX :: 3000000;
	CHUNK_DIM :: 200;

	mesh_surface := make_empty_mesh_no_ebo(FACES_MAX, Voxel_Face); defer clear_mesh(mesh_surface);
	buf_chunk_0 := Shader_Storage.make(CHUNK_DIM * CHUNK_DIM * CHUNK_DIM, size_of(Block)); defer clear(buf_chunk_0);
	buf_chunk_1 := Shader_Storage.make(CHUNK_DIM * CHUNK_DIM * CHUNK_DIM, size_of(Block)); defer clear(buf_chunk_1);
	faces_counter := Atomic_Counter.make(); defer clear(faces_counter);

	shader_fill := make_shader_c(SRC_CHUNK_FILL_COMP, 8, 4, 1); defer clear_shader(*shader_fill);
	shader_iterate := make_shader_c(SRC_CHUNK_ITERATE_COMP, 8, 4, 1); defer clear_shader(*shader_iterate);
	shader_pass := make_shader_c(SRC_CHUNK_TO_VBO_COMP, 8, 4, 1); defer clear_shader(*shader_pass);
	// shader_draw := make_shader_vf(SRC_BLOCK_VERT, SRC_BLOCK_FRAG); defer clear_shader(*shader_draw);
	shader_draw := make_shader_vgf(SRC_BLOCK_VERT, SRC_BLOCK_GEOM, SRC_BLOCK_FRAG); defer clear_shader(*shader_draw);

	time := current_time_monotonic();
	time_from_last_update := 0.;
	update_delay := .1;
	should_update :: () -> bool #expand {
		`time_from_last_update += `dt;
		if `time_from_last_update > update_delay {
			`time_from_last_update -= update_delay;
			return true;
		}
		return false;
	}
	fill :: (buf : Shader_Storage) #expand {
		use(*shader_fill);
			bind(buf, 0);
			set(*shader_fill, "CHUNK_SIZE", cast(u32)CHUNK_DIM);
		compute(shader_fill, CHUNK_DIM, CHUNK_DIM, CHUNK_DIM);
	}
	pass :: (buf : Shader_Storage) #expand {
		reset(faces_counter);
		use(*shader_pass);
			bind(faces_counter, 0);
			bind(buf, 0);
			bind_vbo_as_storage(mesh_surface, 1);
			set(*shader_pass, "CHUNK_SIZE", cast(u32)CHUNK_DIM);
		compute(shader_pass, CHUNK_DIM, CHUNK_DIM, CHUNK_DIM);
	}
	iterate :: (buf_in : Shader_Storage, buf_out : Shader_Storage) #expand {
		use(*shader_iterate);
			bind(buf_in, 0);
			bind(buf_out, 1);
			set(*shader_iterate, "CHUNK_SIZE", cast(u32)CHUNK_DIM);
		compute(shader_iterate, CHUNK_DIM, CHUNK_DIM, CHUNK_DIM);
	}
	swap_buffers :: () #expand {
		buf_chunk_0, buf_chunk_1 = buf_chunk_1, buf_chunk_0;
	}

	fill(buf_chunk_0);
	pass(buf_chunk_0);

	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := cast(float)to_float64_seconds(new_time - time); time = new_time;

		Input.update_window_events();
		move_camera(*camera, xx dt, win_state.pressed_keys, 3.);

		for Input.events_this_frame handle_event(*win_state, it);

		simp.clear_render_target(.1, .3, .3, 1);

		glClear(GL_DEPTH_BUFFER_BIT);
		glEnable(GL_DEPTH_TEST);
		glEnable(GL_CULL_FACE);

		mat_m := make_translation_matrix4(.{0., 1., 0.}) * make_scale_matrix4(.{.5, .5, .5});
		mat_v, mat_p := get_transform_v_p(*camera, .{1200, 800});

		// if should_update() {
		// 	iterate(buf_chunk_0, buf_chunk_1);
		// 	swap_buffers();
		// 	pass(buf_chunk_0);
		// 	// print("faces count = %\n", faces_count);
		// }
		faces_count := get(faces_counter);

		use(shader_draw);
			set(*shader_draw, "u_transform_mv", mat_v * mat_m);
			set(*shader_draw, "u_transform_p", mat_p);
		draw(mesh_surface, GL_POINTS, faces_count);

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}
#scope_file

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
	uniform uint CHUNK_SIZE;
	Block at(ivec3 p) {
		if(p.x < 0 || p.y < 0 || p.z < 0 || p.x >= CHUNK_SIZE || p.y >= CHUNK_SIZE || p.z >= CHUNK_SIZE) {
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
		vert_out.col = a_col;
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

SRC_CHUNK_ITERATE_COMP :: #string GLSL
	#version 430 core

	struct Block {
		uint type;
	};

	layout(std430, binding = 0) buffer u_virtual_chunk_in {
		Block blocks_in[];
	};
	layout(std430, binding = 1) buffer u_virtual_chunk_out {
		Block blocks_out[];
	};

	uniform uint CHUNK_SIZE;
	void set_block(ivec3 p, Block block) {
		if(p.x < 0 || p.y < 0 || p.z < 0 || p.x >= CHUNK_SIZE || p.y >= CHUNK_SIZE || p.z >= CHUNK_SIZE) {
			return;
		}
		blocks_out[CHUNK_SIZE * CHUNK_SIZE * p.z + CHUNK_SIZE * p.y + p.x] = block;
	}
	Block get_block(ivec3 p) {
		if(p.x < 0 || p.y < 0 || p.z < 0 || p.x >= CHUNK_SIZE || p.y >= CHUNK_SIZE || p.z >= CHUNK_SIZE) {
			return Block(0);
		}
		return blocks_in[CHUNK_SIZE * CHUNK_SIZE * p.z + CHUNK_SIZE * p.y + p.x];
	}
	void main() {
		ivec3 p0 = ivec3(gl_GlobalInvocationID.xyz);

		if(p0.x < CHUNK_SIZE && p0.y < CHUNK_SIZE && p0.z < CHUNK_SIZE) {
			uint S = 0;
			bool alive;

			ivec3 d; 
			for(d.x = -1; d.x <= 1; d.x++) {
				for(d.y = -1; d.y <= 1; d.y++) {
					for(d.z = -1; d.z <= 1; d.z++) {
						uint type = get_block(p0 + d).type;
						if(d != ivec3(0)) {
							S += type;
						} else {
							alive = bool(type);
						}
					}
				}
			}

			set_block(p0, Block(uint(
				alive ? 
					(S == 4 || S == 5) : 
					(S == 5)
			)));
		}
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

	uniform uint CHUNK_SIZE;
	void set_block(ivec3 p, Block block) {
		if(p.x < 0 || p.y < 0 || p.z < 0 || p.x >= CHUNK_SIZE || p.y >= CHUNK_SIZE || p.z >= CHUNK_SIZE) {
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
			float dh = hash33(vec3(p0 + 2)).x;
			vec3 r = (vec3(p0) / (CHUNK_SIZE - 1)) * 2 - 1;
			float h = r.y + .5 + dh * .1;

			set_block(p0, h > .0 ? Block(0) : Block(1));
		}
	}
GLSL
