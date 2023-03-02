demo_5 :: () {
	window := create_window(1200, 800, "model loading"); defer close_window(window);
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
		pos : vec4;
		norm : vec4; // TODO -> u32
		col : vec4;
	}
	print("S = %\n", size_of(Voxel_Face));
	Block :: struct {
		type : u32;
	}

	FACES_MAX :: 10000;
	CHUNK_DIM :: 16;

	mesh_surface := make_empty_mesh_no_ebo(FACES_MAX, Voxel_Face); defer clear_mesh(mesh_surface);
	buf_chunk := Shader_Storage.make(CHUNK_DIM * CHUNK_DIM * CHUNK_DIM, size_of(Block)); defer clear(buf_chunk);
	faces_counter := Atomic_Counter.make(); defer clear(faces_counter);

	// mesh := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh);
	// shader := make_shader_vf(SRC_VERT, SRC_DRAW_NORMALS_FRAG); defer clear_shader(*shader);

	shader_fill := make_shader_c(SRC_CHUNK_FILL_COMP, 8, 4, 1); defer clear_shader(*shader_fill);
	shader_pass := make_shader_c(SRC_CHUNK_TO_VBO_COMP, 8, 4, 1); defer clear_shader(*shader_pass);
	// shader_draw := make_shader_vf(SRC_BLOCK_VERT, SRC_BLOCK_FRAG); defer clear_shader(*shader_draw);
	shader_draw := make_shader_vgf(SRC_BLOCK_VERT, SRC_BLOCK_GEOM, SRC_BLOCK_FRAG); defer clear_shader(*shader_draw);

	use(*shader_fill);
		bind(buf_chunk, 0);
	compute(shader_fill, CHUNK_DIM, CHUNK_DIM, CHUNK_DIM);

	reset(faces_counter);
	use(*shader_pass);
		bind(faces_counter, 0);
		bind(buf_chunk, 0);
		bind_vbo_as_storage(mesh_surface, 1);
	compute(shader_pass, CHUNK_DIM, CHUNK_DIM, CHUNK_DIM);
	faces_count := get(faces_counter);
	print("faces count = %\n", faces_count);

	time := current_time_monotonic();
	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;

		Input.update_window_events();
		move_camera(*camera, xx dt, win_state.pressed_keys);

		for Input.events_this_frame handle_event(*win_state, it);

		simp.clear_render_target(.1, .3, .3, 1);

		glClear(GL_DEPTH_BUFFER_BIT);
		glEnable(GL_DEPTH_TEST);
		glEnable(GL_CULL_FACE);
		glPointSize(10);

		mat_v, mat_p := get_transform_v_p(*camera, .{1200, 800});

		use(shader_draw);
			set(*shader_draw, "u_transform_mv", mat_v);
			set(*shader_draw, "u_transform_p", mat_p);
		draw(mesh_surface, GL_POINTS, faces_count);

		simp.swap_buffers(window);
		reset_temporary_storage();
        sleep_milliseconds(10);
	}
}
#scope_file
