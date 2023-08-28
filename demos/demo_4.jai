demo_4 :: () {
	width, height : s32 = 1920, 1080; 
	PARTICLES_MAX :u32: 20000;

	window := create_window(width, height, "advanced particles"); defer close_window(window);
	saved_window_info : Saved_Window_Info;	
	ok:, width, height = toggle_fullscreen(window, true, *saved_window_info);

	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera;

	particle_system : Particle_System; init(*particle_system, PARTICLES_MAX, GLSL_FRAG_PARTICLE); defer deinit(*particle_system);

	get_color :: () -> Vector3 { return hsv2rgb(.{random_get_within_range(0, 1), random_get_within_range(.7, 1.), 1}); }
	get_center :: () -> Vector3 { return Vector3.{random_get_within_range(-1, 1), random_get_within_range(-1, 2), random_get_within_range(-1, 1)} * 3; }

	spawn :: () #expand {
		emit(*particle_system, 
			get_center(), 5, 1.,
			get_color()
		);
	}

	for i: 0..0 spawn();

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
			spawn();
		}

		// simulate
		simulate(*particle_system, xx dt);
		simp.clear_render_target(.0, .0, .0, 1);
		glClear(GL_DEPTH_BUFFER_BIT);

		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE);
			draw(particle_system, get_transform(camera, .{xx width, xx height}), height / cast(float)width);

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

#scope_file
#import "Random";

GLSL_FRAG_PARTICLE :: #string GLSL
	#version 430

	struct Particle_Visual {
		vec2 uv;
		vec3 base_color;
		vec3 aspect_color;
		float angle;
	};
	in Particle_Visual particle_visual;
	out vec4 o_color;

	void main() {
		float r = length(particle_visual.uv);
		// float theta = atan(particle_visual.uv.y, particle_visual.uv.x);

		o_color = vec4(
			particle_visual.base_color,
			r > 1 ? 0 : pow(1 - r, 3)
		);
	}
GLSL