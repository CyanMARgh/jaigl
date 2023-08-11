demo_10 :: () {
	Chunk_Data :: struct {
		is_free : bool;
		// value : s32;
		color : vec3;
	}
	World :: struct {
		visible_chunks_dims :: ivec2.{7, 5};
		// name : string;
		chunk_id_map : Table(ivec2, Chunk_Data);
		visible_chunks_ids : []s32;
		// loaded_chunks : []Chunk_Data;

		visible_chunks_ids_vram : Shader_Storage;
		loaded_chunks_vram : Shader_Storage;
		visible_chunks_corner : ivec2;
	}
	refresh :: (using world : *World, new_corner : ivec2) {
		// visible_chunks_ids_tmp := NewArray(visible_chunks_dims.x * visible_chunks_dims.y, s32);
		// at :: (pos : ivec2) -> s32 #expand {
		// 	pos_old := pos + new_corner - corner;
		// 	if 
		// }

	}
	gen_content_by_cc :: (cc : ivec2) -> Chunk_Data {
		return .{xx((cc.x + cc.y) % 3)};
	}
	maybe_add_chunk :: (using world : *World, cc : ivec2) {
		ptr, is_new := find_or_add(*chunk_id_map, cc);
		if is_new {
			ptr.* = gen_content_by_cc(cc);
		}
	}
	init :: (using world : *World) {
		visible_chunks_corner = .{-3, -2};
		visible_chunks_ids = NewArray(visible_chunks_dims.x * visible_chunks_dims.y, s32);
		for * visible_chunks_ids {
			it.* = xx(it_index);
		}
		visible_chunks_ids_vram = Shader_Storage.from_array(visible_chunks_ids);
	}
	deinit :: (using world : *World) {
		clear(visible_chunks_ids_vram);
		array_free(visible_chunks_ids);
	}

	WIDTH, HEIGHT :: 1200, 800;
	Chunk_Camera :: struct {
		chunk_coord : ivec2;
		local_coord : Vector2;		
		scale := 6.21;
	}

	move_camera :: (using cam : *Chunk_Camera, dt : float, pressed_keys : [1024]bool, speed_factor := 1.) {
		speed :: 1.;
		dir : vec2;
	
		if pressed_keys[#char "W"] dir.y += 1;
		if pressed_keys[#char "S"] dir.y -= 1;
		if pressed_keys[#char "A"] dir.x -= 1;
		if pressed_keys[#char "D"] dir.x += 1;

		local_coord += speed * dir * dt * speed_factor;

		fix :: (c : *s32, l : *float) {
			fl, fr := floor(l.*), fract(l.*);
			c.* += cast(s32)fl;
			l.* = fr;
		}

		fix(*chunk_coord.x, *local_coord.x);
		fix(*chunk_coord.y, *local_coord.y);
	}

	screen_ratio := 1.5;

	window := create_window(WIDTH, HEIGHT, "filters"); defer close_window(window);


	__active_window = window;
	camera : Chunk_Camera;
	win_state : Win_State;
	simp.set_render_target(window);
	world : World;
	init(*world); defer deinit(*world);

	mesh_rect := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_rect);

	shader_final := make_shader_vf(SRC_FINAL_VERT, SRC_FINAL_FRAG); defer clear_shader(*shader_final);

	time := current_time_monotonic();
	time0 := time;

	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);

		Input.update_window_events();
		for Input.events_this_frame handle_event(*win_state, it);
		move_camera(*camera, xx dt, win_state.pressed_keys, 5);

		simp.clear_render_target(.1, .3, .3, 1);

		glClear(GL_DEPTH_BUFFER_BIT);

		use(shader_final);
			bind(world.visible_chunks_ids_vram, 0);
			set(*shader_final, "screen_ratio", screen_ratio);
			set(*shader_final, "screen_scale", camera.scale);
			set(*shader_final, "camera_cc", camera.chunk_coord);
			set(*shader_final, "camera_lc", camera.local_coord);
			set(*shader_final, "visible_chunks_corner", world.visible_chunks_corner);
			set(*shader_final, "visible_chunks_dims", world.visible_chunks_dims);
		draw(mesh_rect);

		simp.swap_buffers(window);
		reset_temporary_storage();
        sleep_milliseconds(10);
	}
}
#scope_file
#import "Hash_Table";

SRC_FINAL_VERT :: #string GLSL
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
SRC_FINAL_FRAG :: #string GLSL
	#version 430 core

	in struct Vert_Out {
		vec2 uv;
	} vert_out;

	layout (std430, binding = 0) buffer u_lists {
		int chunk_ids[];
	};

	uniform float screen_ratio;
	uniform float screen_scale;
	uniform ivec2 camera_cc;
	uniform vec2 camera_lc;
	uniform ivec2 visible_chunks_corner;
	uniform ivec2 visible_chunks_dims;

	int get_id_by_cc(ivec2 cc) {
		cc -= visible_chunks_corner;
		if(cc.x < 0 || cc.y < 0 || cc.x >= visible_chunks_dims.x || cc.y >= visible_chunks_dims.y) {
			return -1;
		}
		return chunk_ids[cc.x + cc.y * visible_chunks_dims.x];
	}

	out vec4 o_color;

	vec2 flip(vec2 uv) {
		// return vec2(uv.x, 1 - uv.y);
		return uv;
	}
	int mmod(int x, int m) {
		return int(mod(x, m));
	}

	vec3 color_of_chunk(ivec2 cc, vec2 lc) {
		const int M = 10;
		int r = mmod(cc.x + cc.y, M);
		int chunk_id =  get_id_by_cc(cc);
		if (chunk_id == -1) return vec3(0);

		return vec3(lc, float(chunk_id) / (visible_chunks_dims.x * visible_chunks_dims.y));
	}

	void main() {	
		vec2 uv = flip(vert_out.uv);
		uv = 2 * uv - 1;
		uv.x *= screen_ratio;
		uv *= screen_scale;
		vec2 fuv = floor(uv);

		ivec2 cc = ivec2(fuv);
		vec2 lc = uv - fuv;

		cc += camera_cc;
		lc += camera_lc;
		cc += ivec2(floor(lc));
		lc = fract(lc);

		o_color = vec4(color_of_chunk(cc, lc), 1);
	}
GLSL
