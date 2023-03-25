demo_4 :: () {
	PARTICLES_MAX :u32: 20000;
	particles_alive : u32;

	window := create_window(1200, 800, "advanced particles"); defer close_window(window);
	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera;

	mesh_particles := make_empty_mesh_no_ebo(PARTICLES_MAX, Particle); defer clear_mesh(mesh_particles);
	
	// shader_generate := make_shader_c(SRC_PARTICLE_GEN_COMP); defer clear_shader(*shader_generate);
	// shader_init := make_shader_c(SRC_PARTICLE_INIT_COMP); defer clear_shader(*shader_init);
	shader_emit := make_shader_c(SRC_PARTICLE_EMIT_COMP, 8, 1, 1); defer clear_shader(*shader_emit);
	shader_pass := make_shader_c(SRC_PARTICLE_TO_VBO_COMP, 8, 1, 1); defer clear_shader(*shader_pass);
	shader_simulate := make_shader_c(SRC_PARTICLE_SIMULATE_COMP, 16, 1, 1); defer clear_shader(*shader_simulate);

	shader_draw := make_shader_vgf(SRC_PARTICLE_DRAW_VERT, SRC_PARTICLE_DRAW_GEOM, SRC_PARTICLE_DRAW_FRAG); defer clear_shader(*shader_draw);

	Particle :: struct {
		pos : vec3;
		size : float;
		color : vec3;
	}

	Particle_Sim :: struct {
		pos, vel : vec3;
		timer : float;
		size : float;
		color : vec3;
		repl : u32;
	}

	buffer_particles_sim := Shader_Storage.make(PARTICLES_MAX, size_of(Particle_Sim)); defer clear(buffer_particles_sim);
	counter_alive := Atomic_Counter.make(); defer clear(counter_alive);

	reset(counter_alive, 0); particles_alive = 0;

	spawn_particles :: (amount : u32, color : vec3, center : vec3) #expand {
		use(`shader_emit);
			bind(`buffer_particles_sim, 0);
			bind(`counter_alive, 0);
			set(*shader_emit, "u_max_particles", `PARTICLES_MAX);
			set(*shader_emit, "u_emit_counter", amount);
			set(*shader_emit, "u_color", color);
			set(*shader_emit, "u_center", center);
		compute(`shader_emit, amount, 1, 1);
	}
	get_color :: () -> vec3 {
		// col := vec3.{random_get_zero_to_one(), random_get_zero_to_one(), random_get_zero_to_one()};
		// return col / max(col.x, col.y, col.z);
		return hsv2rgb(.{random_get_within_range(0, 1), random_get_within_range(.7, 1.), 1});
	}
	get_center :: () -> vec3 {
		return vec3.{random_get_within_range(-1, 1), random_get_within_range(-1, 2), random_get_within_range(-1, 1)} * 3;
	}

	for i: 0..0 spawn_particles(3000, get_color(), get_center());

	particles_alive = get(counter_alive);


	//TODO macro for default loop
	time := current_time_monotonic();
	time_last_spawn := time;
	while !win_state.should_exit {
		// input
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		time_from_previous := to_float64_seconds(new_time - time_last_spawn);
		Input.update_window_events();
		move_camera(*camera, xx dt, win_state.pressed_keys);
		for Input.events_this_frame handle_event(*win_state, it);

		// simulate
		if time_from_previous > .5 {
			time_last_spawn = new_time;
			spawn_particles(1000, get_color(), get_center());
		}

		use(shader_simulate);
			bind(buffer_particles_sim, 0);
			bind(counter_alive, 0);
			set(*shader_simulate, "u_dt", cast(float) dt);
		compute(shader_simulate, particles_alive, 1, 1);

		particles_alive = get(counter_alive);

		// render
		simp.clear_render_target(.0, .0, .0, 1);
		glClear(GL_DEPTH_BUFFER_BIT);

		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE);

		use(shader_pass);
			bind(buffer_particles_sim, 0);
			bind_vbo_as_storage(mesh_particles, 1);
			bind(counter_alive, 0);
		compute(shader_pass, particles_alive, 1, 1);

		use(shader_draw);
			set(*shader_draw, "u_transform", get_transform(*camera, .{1200, 800}));
		draw(mesh_particles, GL_POINTS, particles_alive);

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

#scope_file

#import "Random";
