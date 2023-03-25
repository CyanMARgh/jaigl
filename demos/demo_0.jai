demo_0 :: () {
	mesh_raw_soa, ok := load_obj("res/cow.obj");
	// mesh_raw_soa, ok := load_obj("res/6th_platonic_solid.obj");
	if !ok {
		print("missing file : res/cow.obj");
		exit(1);
	}
	prepare(*mesh_raw_soa);
	defer clear_mesh_raw(mesh_raw_soa);

	window := create_window(1200, 800, "model loading"); defer close_window(window);
	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera = .{position = .{4, 1.5, 5}};

	mesh := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh);
	shader := make_shader_vf(SRC_VERT, SRC_DRAW_NORMALS_FRAG); defer clear_shader(*shader);

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

		mat_v, mat_p := get_transform_v_p(*camera, .{1200, 800});

		use(shader);
			set(*shader, "u_transform_mv", mat_v);
			set(*shader, "u_transform_p", mat_p);
		draw(mesh);

		simp.swap_buffers(window);
		reset_temporary_storage();
        sleep_milliseconds(10);
	}
}