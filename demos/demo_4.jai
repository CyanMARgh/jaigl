demo_4 :: () {
	width, height : s32 = 1920, 1080; 
	PARTICLES_MAX :u32: 20000;

	window := create_window(width, height, "advanced particles"); defer close_window(window);
	saved_window_info : Saved_Window_Info;	
	ok:, width, height = toggle_fullscreen(window, true, *saved_window_info);

	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera;

	particle_system : Particle_System; init(*particle_system, PARTICLES_MAX); defer deinit(*particle_system);
	emitter : Emitter; init(*emitter); defer deinit(*emitter);

	get_color :: () -> Vector3 { return hsv2rgb(.{random_get_within_range(0, 1), random_get_within_range(.7, 1.), 1}); }
	get_center :: () -> Vector3 { return Vector3.{random_get_within_range(-1, 1), random_get_within_range(-1, 2), random_get_within_range(-1, 1)} * 3; }

	for i: 0..0 spawn(*particle_system, *emitter, 3000, get_color(), get_center());

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

		//spawn
		if time_from_previous > .5 {
			time_last_spawn = new_time;
			spawn(*particle_system, *emitter, 1000, get_color(), get_center());
		}

		// simulate
		simulate(*particle_system, xx dt);
		simp.clear_render_target(.0, .0, .0, 1);
		glClear(GL_DEPTH_BUFFER_BIT);
		draw(particle_system, camera, .{xx width, xx height});

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

#scope_file
Particle :: struct {
	pos : Vector3;
	size : float;
	color : Vector3;
}
Particle_Sim :: struct {
	pos, vel : Vector3;
	timer : float;
	size : float;
	color : Vector3;
	repl : u32;
}
Particle_System :: struct {
	max_particles : u32;
	particles_alive : u32;

	buffer_particles_sim : Shader_Storage;
	counter_alive : Atomic_Counter;
	mesh_particles : Mesh;

	shader_simulate : Shader;
	shader_pass : Shader;
	shader_draw : Shader;
}
init :: (using particle_system : *Particle_System, _max_particles : u32) {
	max_particles = _max_particles;
	mesh_particles = make_empty_mesh_no_ebo(max_particles, Particle);
	buffer_particles_sim = Shader_Storage.make(max_particles, size_of(Particle_Sim));
	counter_alive = Atomic_Counter.make();
	reset(counter_alive, 0);

	shader_simulate = make_shader_c(SRC_PARTICLE_SIMULATE_COMP, 16, 1, 1);
	shader_pass = make_shader_c(SRC_PARTICLE_TO_VBO_COMP, 8, 1, 1);
	shader_draw = make_shader_vgf(SRC_PARTICLE_DRAW_VERT, SRC_PARTICLE_DRAW_GEOM, SRC_PARTICLE_DRAW_FRAG);
}
deinit :: (using particle_system : *Particle_System) {
	clear_shader(*shader_draw);
	clear_shader(*shader_simulate);
	clear_shader(*shader_pass);

	clear(counter_alive);
	clear(buffer_particles_sim);
	clear_mesh(mesh_particles);
}
simulate :: (using particle_system : *Particle_System, dt : float) {
	use(shader_simulate);
		bind(buffer_particles_sim, 0);
		bind(counter_alive, 0);
		set(*shader_simulate, "u_dt", cast(float) dt);
	compute(shader_simulate, particles_alive, 1, 1);
	particles_alive = get(counter_alive);
}
draw :: (using particle_system : Particle_System, camera : Camera, screen_size : Vector2) {
	use(shader_pass);
		bind(buffer_particles_sim, 0);
		bind_vbo_as_storage(mesh_particles, 1);
		bind(counter_alive, 0);
	compute(shader_pass, particles_alive, 1, 1);

	glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE);
	use(shader_draw);
		set(*shader_draw, "u_transform", get_transform(*camera, screen_size));
	draw(mesh_particles, GL_POINTS, particles_alive);
}
Emitter :: struct {
	shader_emit : Shader;
}
init :: (using emitter : *Emitter)  {
	shader_emit = make_shader_c(SRC_PARTICLE_EMIT_COMP, 8, 1, 1);
}
deinit :: (using emitter : *Emitter) {
	clear_shader(*shader_emit);
}
spawn :: (using particle_system : *Particle_System, using emitter : Emitter, amount : u32, color : Vector3, center : Vector3) {
	use(shader_emit);
		bind(buffer_particles_sim, 0);
		bind(counter_alive, 0);
		set(*shader_emit, "u_max_particles", max_particles);
		set(*shader_emit, "u_emit_counter", amount);
		set(*shader_emit, "u_color", color);
		set(*shader_emit, "u_center", center);
	compute(shader_emit, amount, 1, 1);
	particles_alive = get(counter_alive);
}

#import "Random";
