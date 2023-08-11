demo_11 :: () {
	window := create_window(1600, 900, "model loading"); defer close_window(window);
	__active_window = window;
	simp.set_render_target(window);

	win_state : Win_State;
	camera : Camera = .{position = .{4, 1.5, 5}};

	mask := load_texture("res/screenshot_with_uv_skin_3.png", interpolation = GL_NEAREST);
	// mask := load_texture("res/uv64.png", interpolation = GL_NEAREST);
	skin := load_texture("res/skin.png", interpolation = GL_NEAREST);
	mesh_rect := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_rect);
	shader_mask := make_shader_vf(SRC_VERT_MASK, SRC_FRAG_MASK); defer clear_shader(*shader_mask);

	time := current_time_monotonic();
	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;

		Input.update_window_events();

		for Input.events_this_frame handle_event(*win_state, it);
		simp.clear_render_target(.1, .3, .3, 1);

		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		use(shader_mask);
			bind(mask, 0);
			bind(skin, 1);
		draw(mesh_rect);

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

SRC_VERT_MASK :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec2 a_uv;

	out vec2 uv;

	void main() {
		uv = a_uv;
		gl_Position = vec4(a_pos, 1);
	}
GLSL

SRC_FRAG_MASK :: #string GLSL
	#version 430 core

	layout(binding = 0) uniform sampler2D u_mask;
	layout(binding = 1) uniform sampler2D u_skin;

	in vec2 uv;
	out vec4 o_color;

	vec2 flip(vec2 uv) {
		return vec2(uv.x, 1 - uv.y);
		// return uv;
	}


	void main() {
		vec4 col_src = texture(u_mask, flip(uv));
		// if(uv.x > 1) {
			if(col_src.z > 0) {
				o_color = col_src;
			} else {
				o_color = texture(u_skin, vec2(col_src.x, col_src.y));
			}
		// } else {
		// 	o_color = col_src;
		// }
	}
GLSL
