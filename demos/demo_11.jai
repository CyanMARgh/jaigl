demo_11 :: () {
	width, height : s32 = 1200, 800; 

	mesh_raw_soa, ok := load_obj("res/stanford_bunny.obj");
	prepare(*mesh_raw_soa);
	defer clear_mesh_raw(mesh_raw_soa);

	window := create_window(width, height, "filters"); defer close_window(window);
	camera : Camera;

	__active_window = window;
	win_state : Win_State;
	simp.set_render_target(window);

	mesh_bunny := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh_bunny);
	mesh_rect := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_rect);

	shader_solid := make_shader_vf(SRC_VERT_MINIMUM, SRC_FRAG_SOLID); defer clear_shader(*shader_solid);
	shader_outline := make_shader_vf(SRC_VERT_INFLATE, SRC_FRAG_SINGLE_COLOR); defer clear_shader(*shader_outline);

	time := current_time_monotonic();
	time0 := time;

	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);

		Input.update_window_events();
		for Input.events_this_frame handle_event(*win_state, it);
		move_camera(*camera, xx dt, win_state.pressed_keys, 5);

		mat_vp := get_transform(camera, .{xx width, xx height});
		mat_m := make_scale_matrix4(.{100, 100, 100});

		for Draw_To_Framebuffer.{window = *window, background = Vector4.{0, 0, 1, 1}} {
			{
				glEnable(GL_CULL_FACE); defer glDisable(GL_CULL_FACE);
				glCullFace(GL_FRONT);
				glEnable(GL_DEPTH_TEST);

				for *shader_outline {
					set("u_time", cast(float)current_time);
					set("u_m", mat_m);
					set("u_vp", mat_vp);
					draw(mesh_bunny);
				}
			}
			{
				glEnable(GL_CULL_FACE); defer glDisable(GL_CULL_FACE);
				glCullFace(GL_BACK);
				glEnable(GL_DEPTH_TEST);

				for *shader_solid {
					set("u_time", cast(float)current_time);
					set("u_m", mat_m);
					set("u_vp", mat_vp);
					draw(mesh_bunny);
				}
			}
		}
		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}
#scope_file
Draw_To_Framebuffer :: struct {
	buffer : *Frame_Buffer;
	window : *Window_Type;
	background := Vector4.{1, 1, 1, 1};
	clear_color := true;
	clear_z_buffer := true;
}
for_expansion :: (using dtf : Draw_To_Framebuffer, body : Code, flags : For_Flags) #expand {
	`it, `it_index := 0;
	if buffer {
		bind(buffer);
	} else if window {
		simp.set_render_target(window.*);
	} else {
		assert(false);
	}
	if clear_z_buffer {
		glClear(GL_DEPTH_BUFFER_BIT);		
	}
	if clear_color {
		simp.clear_render_target(background.x, background.y, background.z, background.w);
	}
	#insert body;
}
for_expansion :: (shader : *Shader, body : Code, flags : For_Flags) #expand {
	`set :: (name : string, value : $T) #expand {
		set(shader, name, value);
	}
	`it, `it_index := 0;

	use(shader);
	#insert body;
}

SRC_VERT_MINIMUM :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 2) in vec3 a_norm;

	uniform mat4 u_vp;
	uniform mat4 u_m;

	out struct Vert_Out {
		vec3 pos;
		vec3 norm;
	} vert_out;

	void main() {
		vec4 p = u_m * vec4(a_pos, 1);
		vert_out.pos = p.xyz;
		vert_out.norm = a_norm;
		gl_Position = u_vp * p;

	}
GLSL
SRC_VERT_INFLATE :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 2) in vec3 a_norm;

	uniform float u_time;

	uniform mat4 u_vp;
	uniform mat4 u_m;

	out struct Vert_Out {
		vec3 pos;
		vec3 norm;
	} vert_out;

	void main() {
		float offset = (sin(u_time * 3) + 1) * .1;
		vec4 p = (u_m * vec4(a_pos, 1)) + vec4(a_norm * offset, 0);
		vert_out.pos = p.xyz;
		vert_out.norm = a_norm;
		gl_Position = u_vp * p;

	}
GLSL
SRC_FRAG_SOLID :: #string GLSL
	#version 430 core

	in struct Vert_Out {
		vec3 pos;
		vec3 norm;
	} vert_out;

	layout(location = 0) out vec4 o_color;

	void main() {
		float brightness = min(1, max(dot(normalize(vert_out.norm), vec3(1, 0, 0)), 0) + .3);

		ivec3 ipos = ivec3(floor(vert_out.pos * 2));
		vec3 color = mod(ipos.x + ipos.y + ipos.z, 2) == 0 ? vec3(1, .5, .5) : vec3(.5, 1, .5);

		o_color = vec4(color * brightness, 1);
	}
GLSL
SRC_FRAG_SINGLE_COLOR :: #string GLSL
	#version 430 core
	in struct Vert_Out {
		vec3 pos;
		vec3 norm;
	} vert_out;

	uniform vec3 color = vec3(0);

	layout(location = 0) out vec4 o_color;

	void main() {
		o_color = vec4(color, 1);
	}
GLSL