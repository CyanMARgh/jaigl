demo_3 :: () {
	width, height : u32 = 1200, 800;
	max_nodes : u32 =  width * height * 5;

	mesh_raw_soa, ok := load_obj("res/cow.obj");
	if !ok exit(1);
	prepare(*mesh_raw_soa);
	defer clear_mesh_raw(mesh_raw_soa);

	window := create_window(width, height, "order independent transparency"); defer close_window(window);
	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera;

	mesh_scene := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh_scene);
	mesh_screen := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_screen);

	Color_Node :: struct {
		color : vec4;
		prev : u32;
		depth : float;
	}
	buf_nodes := Shader_Storage.make(max_nodes, size_of(Color_Node)); defer clear(buf_nodes);
	counter_nodes := Atomic_Counter.make(); defer clear(counter_nodes);
	//											TODO    	----. 
	buf_heads := make_image(width, height, GL_R32UI);

	shader_to_nodes := make_shader_vf(SRC_VERT, SRC_OIT_TO_NODES_FRAG); defer clear_shader(*shader_to_nodes);
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
		move_camera(*camera, xx dt, win_state.pressed_keys);
		for Input.events_this_frame handle_event(*win_state, it);

		// render
		use(shader_reset);
			bind_as_storage(buf_heads, 0);
		compute(shader_reset, width, height, 1);
		reset(counter_nodes);

		// scene
		{
			simp.clear_render_target(.1, .3, .3, 1);
			glClear(GL_DEPTH_BUFFER_BIT);

			mat_v, mat_p := get_transform_v_p(*camera, .{1200, 800});
			//TODO set(*Shader, ..Any)
			use(shader_to_nodes);
				set(*shader_to_nodes, "u_transform_mv", mat_v);
				set(*shader_to_nodes, "u_transform_p", mat_p);
				set(*shader_to_nodes, "u_max_nides", max_nodes);
				set(*shader_to_nodes, "u_time", cast(float)current_time);
				bind_as_storage(buf_heads, 0);
				bind(counter_nodes, 0);
				bind(buf_nodes, 0);
			draw(mesh_scene);
		}

		simp.clear_render_target(.3, .1, .3, 1);
		glClear(GL_DEPTH_BUFFER_BIT);
		use(shader_from_nodes);
			bind_as_storage(buf_heads, 0);
			bind(counter_nodes, 0);
			bind(buf_nodes, 0);
		draw(mesh_screen);

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}