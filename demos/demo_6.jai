demo_6 :: () {
	window := create_window(1200, 800, "integers in vbo"); defer close_window(window);
	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera;

	S32 :: struct { coord : s32; }
	F32 :: struct { coord : float; }

	coord : int = 3;

	mesh_src : Mesh_Raw;
	mesh_src.points.data = xx *coord;
	mesh_src.points.count = 1;

	mesh_surface := make_mesh(mesh_src, S32); defer clear_mesh(mesh_surface);

	shader_draw := make_shader_vf(SRC_INT_TEST_VERT, SRC_INT_TEST_FRAG); defer clear_shader(*shader_draw);

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
		glPointSize(15);

		use(shader_draw);
		draw(mesh_surface, GL_POINTS);

		simp.swap_buffers(window);
		reset_temporary_storage();
        sleep_milliseconds(10);
	}
}