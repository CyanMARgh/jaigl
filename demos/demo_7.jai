demo_7 :: () {
	width, height : s32 = 1920, 1080;
	max_nodes : u32 = xx(width * height * 20);

	mesh_particles := concat(
		gen_tree(2, .{0,  1}),
		// gen_tree(3, .{-2.5,  2}),
		gen_tree(4, .{ 2,  2}),
		// gen_tree(3, .{-2, -1}),
		// gen_tree(5, .{ 2, -2}),
	);

	defer clear_mesh_raw(mesh_particles);

	window := create_window(width, height, "watercolor"); defer close_window(window);
	ok : bool;
	saved_window_info : Saved_Window_Info;	
	ok, width, height = toggle_fullscreen(window, true, *saved_window_info);
	__active_window = window;
	simp.set_render_target(window);
	win_state : Win_State;
	camera : Camera;

	mesh_scene := make_mesh(mesh_particles, Particle); defer clear_mesh(mesh_scene);
	mesh_screen := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_screen);

	Color_Node :: struct {
		color : vec4;
		prev : u32;
		depth : float;
	}
	buf_nodes := Shader_Storage.make(max_nodes, size_of(Color_Node)); defer clear(buf_nodes);
	counter_nodes := Atomic_Counter.make(); defer clear(counter_nodes);
										// TODO    	----. 
	buf_heads := make_image(xx width, xx height, GL_R32UI);

	shader_to_nodes := make_shader_vgf(SRC_BLOT_DRAW_VERT, SRC_BLOT_DRAW_GEOM, SRC_BLOT_OIT_DRAW_FRAG); defer clear_shader(*shader_to_nodes);
	shader_from_nodes := make_shader_vf(SRC_SCREEN_VERT, SRC_OIT_FROM_NODES_FRAG); defer clear_shader(*shader_from_nodes);
	shader_reset := make_shader_c(SRC_OIT_CLEAR_COMP, 8, 4, 1); defer clear_shader(*shader_reset);

	time := current_time_monotonic();
	time0 := time;
	while !win_state.should_exit {
		// sim & input
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);
		Input.update_window_events();
		camera_rail(*camera, xx current_time);

		// move_camera(*camera, xx dt, win_state.pressed_keys);
		for Input.events_this_frame handle_event(*win_state, it);

		// render
		use(shader_reset);
			bind_as_storage(buf_heads, 0);
		compute(shader_reset, xx width, xx height, 1);
		reset(counter_nodes);

		// scene
		{
			simp.clear_render_target(.1, .3, .3, 1);
			glClear(GL_DEPTH_BUFFER_BIT);

			// glEnable(GL_BLEND);
			// glBlendFunc(GL_SRC_ALPHA, GL_ONE);

			mat_mvp := get_transform(*camera, vec2.{xx width, xx height});
			//TODO set(*Shader, ..Any)
			use(shader_to_nodes);
				set(*shader_to_nodes, "u_transform_mvp", mat_mvp);
				// set(*shader_to_nodes, "u_transform_p", mat_p);
				set(*shader_to_nodes, "u_max_nodes", max_nodes);
				set(*shader_to_nodes, "u_time", cast(float)current_time);
				bind_as_storage(buf_heads, 0);
				bind(counter_nodes, 0);
				bind(buf_nodes, 0);
				set(*shader_to_nodes, "u_screen_size", vec2.{xx width, xx height});
			draw(mesh_scene, GL_POINTS);
		}

		// simp.clear_render_target(.3, .1, .3, 1);
		glClear(GL_DEPTH_BUFFER_BIT);
		use(shader_from_nodes);
			bind_as_storage(buf_heads, 0);
			bind(counter_nodes, 0);
			bind(buf_nodes, 0);
			set(*shader_from_nodes, "u_screen_size", vec2.{xx width, xx height});
		draw(mesh_screen);

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

#scope_file
#import "Random";

Particle :: struct {
	coord : vec3;
	col_maj, col_min : vec3;
	size : float;
}
concat :: (meshes : ..Mesh_Raw) -> Mesh_Raw {
	size, offset := 0;
	for meshes {
		assert(it.indices.count == 0);
		size += it.points.count;
	}
	points_total := NewArray(size, float);
	for meshes {
		s := it.points.count;
		memcpy(xx(points_total.data + offset), xx it.points.data, s * size_of(float));
		offset += s;
	}
	for meshes clear_mesh_raw(it);
	return .{points_total, .[]};
}
gen_tree :: (size : float, pos : vec2) -> Mesh_Raw {
	return concat(
		gen_trunk(size, vec3.{pos.x, 0, pos.y}, cast(u32) (30 * size)),
		gen_leaves(pow(size / 8, .5), vec3.{pos.x, size, pos.y}, cast(u32) (2000 * pow(size / 4, 1.5))),
		gen_leaves(pow(size / 5, .5), vec3.{pos.x, size - 1, pos.y}, cast(u32) (50 * pow(size / 4, 1.5))),		
	);
}

gen_trunk :: (height : float, offset : vec3, count : u32) -> Mesh_Raw {
	particles := NewArray(count, Particle);
	s0, s1 := .5,  2.;
	h0, h1 := height, 0.;
	r0, r1 := .6,  1.3;
	k := hash22(offset.xy) * .5;

	for * p, i : particles {
		t := cast(float) i / count;
		t *= t;
		pos := vec3.{t * k.x, mix(h0, h1, t), t * k.y} + offset;
		pos += vec3.{perlin(pos.xy * .5), perlin(vec2.{pos.y, pos.x} * 5.), 0} * mix(r0, r1, t) * (height / 3);
		<<p = .{
			pos,
			.{0, 0, 0},
			vec3.{181, 153, 107} / 255.,
			mix(s0, s1, t)
		};
	}
	particles_f : []float;
	particles_f.data, particles_f.count = xx particles.data, particles.count * (size_of(Particle) / size_of(float));
	return .{particles_f, .[]};
}

gen_leaves :: (size : float, offset : vec3, count : u32) -> Mesh_Raw {
	particles := NewArray(count, Particle);

	h := hash22(offset.xy);
	col_offset := vec3.{1 + h.x * .1, 1 + h.y * .05, 1 + h.y * .1};

	col_maj0 := (vec3.{253, 150, 255} / 255.) * col_offset;
	col_maj1 := vec3.{1, 1, 1} * col_offset;
	col_min := (vec3.{181, 9, 184} / 255.) * col_offset;

	rand_vec3 :: (l : float, r : float) -> vec3 {
		return .{
			random_get_within_range(l, r),
			random_get_within_range(l, r),
			random_get_within_range(l, r)
		};
	}
	rand_in_sphere :: () -> vec3 {
		p := vec3.{1, 1, 1};
		while length(p) > 1 {
			p = rand_vec3(-1, 1);
		}
		return p;
	}

	for * particles {
		k1 := random_get_zero_to_one();
		k2 := random_get_zero_to_one();
		pos := vec3.{3, 2, 3} * rand_in_sphere() * size;
		pos += vec3.{perlin(pos.xy), 0, 0} * 2 + offset;

		<<it = .{
			pos,
			mix(col_maj0, col_maj1, k1 * k1), col_min,
			random_get_within_range(0.3, 1)
		};
	}
	particles_f : []float;
	particles_f.data, particles_f.count = xx particles.data, particles.count * (size_of(Particle) / size_of(float));
	return .{particles_f, .[]};
}

SRC_BLOT_DRAW_VERT :: #string GLSL
	#version 430 core

	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec3 a_col_maj;
	layout (location = 2) in vec3 a_col_min;
	layout (location = 3) in float a_size;

	uniform mat4 u_transform_mvp;

	out struct Vert_Out {
		vec3 col_maj, col_min;
		float size;
	} vert_out;

	void main() {
		gl_Position = u_transform_mvp * vec4(a_pos, 1.);
		vert_out.col_maj = a_col_maj;
		vert_out.col_min = a_col_min;
		vert_out.size = a_size;
	}
GLSL
SRC_BLOT_DRAW_GEOM :: #string GLSL
	#version 430 core

	layout (points) in;
	layout (triangle_strip, max_vertices = 4) out;

	uniform vec2 u_screen_size;
	const float u_particle_size = 60;

	in struct Vert_Out {
		vec3 col_maj, col_min;
		float size;
	} vert_out[];

	out struct Geom_Out {
		vec3 col_maj, col_min;
		float size;
		vec2 uv;
	} geom_out;

	void add_point(vec4 p0, vec2 dxy, vec4 M, float s) {
		s += .5;
		dxy *= s;
		gl_Position = p0 + vec4(dxy, 0, 0) * M; 
		geom_out.uv = dxy;
		EmitVertex();
	}

	void main() {
		float s = vert_out[0].size;
		vec4 M = vec4(u_particle_size / (vec2(u_screen_size.x / u_screen_size.y, 1) * 1500), 1., 1.), p0 = gl_in[0].gl_Position;
	#ifdef SCREEN_SCALE
		p0.xyz /= p0.w; p0.w = 1;
	#else
		M.xyz *= 4;
	#endif

		geom_out.col_maj = vert_out[0].col_maj;
		geom_out.col_min = vert_out[0].col_min;
		geom_out.size = vert_out[0].size;

		if(s > 0) {
			add_point(p0, vec2(-1, -1), M, s);
			add_point(p0, vec2( 1, -1), M, s);
			add_point(p0, vec2(-1,  1), M, s);
			add_point(p0, vec2( 1,  1), M, s);

			EndPrimitive();
		}
	}
GLSL
SRC_BLOT_DRAW_FRAG :: #string GLSL
	#version 430 core

	uniform vec2 u_screen_size;

	in struct Geom_Out {
		vec3 col_maj, col_min;
		float size;
		vec2 uv;
	} geom_out;

	out vec4 o_color;

	vec4 get_color() {
		// float d0 = linearize_depth(texture(u_tex, (gl_FragCoord.xy) / u_screen_size).r);
		// float d1 = linearize_depth(gl_FragCoord.z);

		float depth_factor = 1;																//clamp((d0 - d1) / 0.01, 0, 1);
		float l = length(geom_out.uv);
		float dist_factor = l < geom_out.size ? 1 : 0; pow(clamp(1 - l, 0, 1), 2); 			//pow(max(1 - length(a_uv), 0), 2);
		float time_factor = 1;																// sin((u_time + 10) * (1 + freq) * 2) * .5 + .5;

		float brightness = depth_factor * dist_factor * time_factor;
		vec4 color = vec4(geom_out.col_maj, brightness);

		// if(color.w > eps) {
		// 	add_node(color, gl_FragCoord.z);
		// }
		return color;
	}

	void main() {
		o_color = get_color();
	}
GLSL
SRC_BLOT_OIT_DRAW_FRAG :: #string GLSL
	#version 430 core

	uniform vec2 u_screen_size;

	in struct Geom_Out {
		vec3 col_maj, col_min;
		float size;
		vec2 uv;
	} geom_out;

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
	uniform uint max_nodes = 1200 * 800 * 20;

	void add_node(vec4 color, float depth) {
		ivec2 coord = ivec2(gl_FragCoord.xy);
		uint node_id = atomicCounterIncrement(pixel_counter);
		if(node_id < max_nodes) {
			uint prev = imageAtomicExchange(u_heads, coord, node_id);
			nodes[node_id] = Node(color, prev, depth);
		}
	}

	const int M1 = 2, M2 = 2;
	vec2 hash22(vec2 p) {
		p = p * mat2(127.1, 311.7, 269.5 ,183.3);
		p = -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
		return sin(p * 6.283 + geom_out.size * vec2(124.1, 8123.1)); // size as seed
	}

	float perlin_level(vec2 p) {
		vec2 pi = floor(p);
		vec2 pf = p - pi;
		vec2 w = pf * pf * (3. - 2. * pf);

		float f00 = dot(hash22(pi + vec2(0., 0.)),pf - vec2(0., 0.));
		float f01 = dot(hash22(pi + vec2(0., 1.)),pf - vec2(0., 1.));
		float f10 = dot(hash22(pi + vec2(1., 0.)),pf - vec2(1., 0.));
		float f11 = dot(hash22(pi + vec2(1., 1.)),pf - vec2(1., 1.));

		return mix(mix(f00, f10, w.x), mix(f01, f11, w.x), w.y);   
	}
	float perlin(vec2 p) {
		float a = 1., r = 0., s=0.;    
		for(int i = 0; i < M1; i++) {
			r += a * perlin_level(p);
			s += a; p *= 2.; a *= .5;
		}
		return r / s;
	}

	vec4 get_color() {
		// float d0 = linearize_depth(texture(u_tex, (gl_FragCoord.xy) / u_screen_size).r);
		// float d1 = linearize_depth(gl_FragCoord.z);

		float depth_factor = 1;																//clamp((d0 - d1) / 0.01, 0, 1);
		float r = length(geom_out.uv) / 2;

		float p1 = perlin(geom_out.uv * .8) * .4;

		float l = r - geom_out.size / 2 + p1;
		// float dist_factor = l < geom_out.size ? 1 : 0; pow(clamp(1 - l, 0, 1), 2); 			//pow(max(1 - length(a_uv), 0), 2);
		float time_factor = 1;													// sin((u_time + 10) * (1 + freq) * 2) * .5 + .5;

		vec2 v = normalize(hash22(vec2(0, 1)));
		float H = 3;
		mat2x2 Mv = mat2x2(H * v.x, v.y, -H * v.y, v.x);
		float p2 = perlin(Mv * geom_out.uv + 1) * .3 + .5;

		float dist_factor = l > 0 ? exp(-l * 30) : mix(.8, 1., exp(l * 3));

		float brightness = depth_factor * dist_factor * time_factor * .5;
		vec4 color = vec4(mix(geom_out.col_maj, geom_out.col_min, p2 * p2 * p2), brightness);

		return color;
	}

	const float eps = 0.001;
	// out vec4 o_color;
	void main() {
		vec4 color = get_color();
		// o_color = color;

		if(color.w > eps) {
			add_node(color, gl_FragCoord.z);
		}
	}
GLSL
