demo_2 :: () {
	width, height : s32 = 1920, 1080; 

	window := create_window(width, height, "magnetic pendulum fractal"); defer close_window(window);
	ok : bool;
	saved_window_info : Saved_Window_Info;	
	ok, width, height = toggle_fullscreen(window, true, *saved_window_info);

	win_state : Win_State;
	simp.set_render_target(window);

	mesh_screen := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_screen);

	state_buf := make_storage(xx width, xx height, GL_RGBA32F); defer clear_texture(state_buf);

	shader_screen := make_shader_vf(SRC_SCREEN_VERT, SRC_PENDULUM_SCREEN_FRAG); defer clear_shader(*shader_screen);
	shader_init := make_shader_c(SRC_PENDULUM_INIT_COMP); defer clear_shader(*shader_init);
	shader_iterate := make_shader_c(SRC_PENDULUM_ITERATE_COMP); defer clear_shader(*shader_iterate);

	use(shader_init);
		bind_as_storage(state_buf, 0);
	compute(shader_init, xx width, xx height, 1);	
	print("\n\n");

	time := current_time_monotonic();
	time0 := time;

	started := true;
	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);

		Input.update_window_events();
		for Input.events_this_frame handle_event(*win_state, it);

		simp.clear_render_target(0, 0, 0, 1);
		glClear(GL_DEPTH_BUFFER_BIT);

		if started {
			use(shader_iterate);
				bind_as_storage(state_buf, 0);
				set(*shader_iterate, "u_time", cast(float) current_time);
				set(*shader_iterate, "u_dtime", cast(float) dt);
				// set(*shader_iterate)
			compute(shader_iterate, xx width, xx height, 1);

			use(shader_screen);
				bind(state_buf, 0);
			draw(mesh_screen);
		} else if win_state.pressed_keys[#char "S"] {
			started = true;
		}

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}
