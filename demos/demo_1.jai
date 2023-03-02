demo_1 :: () {
	window := create_window(1200, 800, "framebuffer test"); defer close_window(window);
	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera;

	mesh_raw_soa, ok := load_obj("res/6th_platonic_solid.obj");
	if !ok {
		print("missing file : res/6th_platonic_solid.obj\n");
		exit(1);
	}
	prepare(*mesh_raw_soa); defer clear_mesh_raw(mesh_raw_soa);

	mesh_scene := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh_scene);
	// shader := make_shader_vgf(SRC_PARTICLE_VERT, SRC_PARTICLE_GEOM, SRC_PARTICLE_FRAG); defer clear_shader(*shader);
	mesh_rect := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_rect);

	shader_scene := make_shader_vf(SRC_VERT, SRC_DRAW_NORMALS_FRAG); defer clear_shader(*shader_scene);
	shader_screen := make_shader_vf(SRC_SCREEN_VERT, SRC_SCREEN_FRAG); defer clear_shader(*shader_screen);

	frame_buffer := make_frame_buffer(1200, 800); defer clear_frame_buffer(*frame_buffer);

	time := current_time_monotonic();
	time0 := time;

	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);

		Input.update_window_events();
		for Input.events_this_frame handle_event(*win_state, it);

		camera_rail(*camera, xx current_time);

		{
			bind(frame_buffer); defer simp.set_render_target(window);

			simp.clear_render_target(.0, .0, .2, 1);
			glClear(GL_DEPTH_BUFFER_BIT);
			
			glDepthMask(GL_TRUE);	
			glEnable(GL_DEPTH_TEST);

			use(shader_scene);
				transform := get_transform(*camera, .{1200, 800});
				set(*shader_scene, "u_transform", transform);
			draw(mesh_scene);			
		}

		simp.clear_render_target(.1, .0, .2, 1);
		glClear(GL_DEPTH_BUFFER_BIT);
		
		use(shader_screen);
			bind(frame_buffer.tex_color, 0);
			bind(frame_buffer.tex_depth, 1);
		draw(mesh_rect);			

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}
