demo_8 :: () {
window := create_window(1920, 1080, "magic eye"); defer close_window(window);
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

	// pattern := load_texture("res/pattern.png");

	shader_scene := make_shader_vf(SRC_VERT, SRC_DRAW_NORMALS_FRAG); defer clear_shader(*shader_scene);
	shader_screen := make_shader_vf(SRC_SCREEN_VERT, SRC_SCREEN_STEREO_FRAG); defer clear_shader(*shader_screen);

	frame_buffer := make_frame_buffer(1920, 1080); defer clear_frame_buffer(*frame_buffer);

	time := current_time_monotonic();
	time0 := time;

	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);

		Input.update_window_events();
		for Input.events_this_frame handle_event(*win_state, it);

		move_camera(*camera, xx dt, win_state.pressed_keys);
		// camera_rail(*camera, xx current_time);

		{
			bind(frame_buffer); defer simp.set_render_target(window);

			simp.clear_render_target(.0, .0, .2, 1);
			glClear(GL_DEPTH_BUFFER_BIT);
			
			glDepthMask(GL_TRUE);	
			glEnable(GL_DEPTH_TEST);

			mat_v, mat_p := get_transform_v_p(*camera, .{1920, 1080});

			use(shader_scene);
				set(*shader_scene, "u_transform_mv", mat_v);
				set(*shader_scene, "u_transform_p", mat_p);
			draw(mesh_scene);
		}

		simp.clear_render_target(.1, .0, .2, 1);
		glClear(GL_DEPTH_BUFFER_BIT);
		
		use(shader_screen);
			bind(frame_buffer.tex_color, 0);
			bind(frame_buffer.tex_depth, 1);
			// bind(pattern, 2);
			set(*shader_screen, "u_time", cast(float)current_time);
		draw(mesh_rect);			

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}
#scope_file 
SRC_SCREEN_STEREO_FRAG :: #string GLSL
	#version 430 core

	layout(binding = 0) uniform sampler2D u_color;
	layout(binding = 1) uniform sampler2D u_depth;
	// layout(binding = 2) uniform sampler2D u_pattern;

	uniform float u_time;

	in struct Vert_Out {
		vec2 uv;
	} vert_out;

	const vec2 resolution = vec2(1920, 1080);
	const float fPixelRepeat = 250.0;
	const float fDepthScale = 600.0;

	const float stripes = 8;

	out vec4 o_color;

	float z_near = .01, z_far  = 100;
	float delinearize_depth(float z0) {
		float z1 = (2 * z_near * z_far) / z0;
		float z2 = ((z_far + z_near) - z1) / (z_far - z_near);
		float z3 = (z2 + 1) / 2;
		return z3;
	}
	float linearize_depth(float depth)  {
		float z = depth * 2 - 1; 
		return (2 * z_near * z_far) / (z_far + z_near - z * (z_far - z_near));	
	}
	float get_depth(vec2 P) {
		float d1 = texture(u_depth, P / resolution).r;
		// float d2 = linearize_depth(d1);
		return (1 - delinearize_depth(
					// pow(linearize_depth(d1), sin(u_time) > 0 ? 1 : 2)
					pow(linearize_depth(d1), 1.6)
		));
	}
	float hash12(vec2 p) {
		vec3 p3  = fract(vec3(p.xyx) * .1031);
		p3 += dot(p3, p3.yzx + 33.33);
		return fract((p3.x + p3.y) * p3.z);
	}
	float hash13(vec3 p3) {
		p3  = fract(p3 * .1031);
		p3 += dot(p3, p3.zyx + 31.32);
		return fract((p3.x + p3.y) * p3.z);
	}
	vec4 stereogram(vec2 P) {
		for(int i = 0; i < 64 && P.x >= 0; i++) {
			P.x += -fPixelRepeat + get_depth(P) * fDepthScale;
		}
		P = mod(P, fPixelRepeat);
		P.x = floor(P.x);
		vec2 uv = P / fPixelRepeat;

		// return texture(u_pattern, uv);
		return vec4(vec3(hash13(vec3(uv * 20., u_time))), 1);
	}

	vec2 flip(vec2 uv) {
		// return vec2(uv.x, 1 - uv.y);
		return uv;
	}

	void main() {
		vec2 uv = vert_out.uv;

		// if(gl_FragCoord.x < 600) {
		// 	float d = texture(u_depth, uv).x;
		// 	vec3 col =  texture(u_color, flip(uv)).xyz;
		// 	o_color = vec4(gl_FragCoord.y < 400 ? vec3(linearize_depth(d)) : col, 1);
		// } else {
			// o_color = texture(u_pattern, uv);
			o_color = stereogram(gl_FragCoord.xy);
		// }
	}
GLSL