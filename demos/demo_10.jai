demo_10 :: () {
	width, height : s32 = 1200, 800; 

	// mesh_raw_soa, ok := load_obj("res/sphere2.obj");
	mesh_raw_soa, ok := load_obj("res/stanford_bunny.obj");
	// mesh_raw_soa, ok := load_obj("res/6th_platonic_solid.obj");
	prepare(*mesh_raw_soa);
	defer clear_mesh_raw(mesh_raw_soa);

	window := create_window(width, height, "filters"); defer close_window(window);
	camera : Camera;

	__active_window = window;
	win_state : Win_State;
	simp.set_render_target(window);

	glass_buffer_0 := make_frame_buffer(1200, 800, add_alpha=true, hdr=true); defer clear_frame_buffer(*glass_buffer_0);
	glass_buffer_1 := make_frame_buffer(1200, 800, add_alpha=true, hdr=true); defer clear_frame_buffer(*glass_buffer_1);

	copy_content :: (dst : *Texture, src : Texture) {
		assert(dst.width == src.width && dst.height == src.height);
		glCopyImageSubData(
			src.id,
			GL_TEXTURE_2D,
			0, 0, 0, 0,
			dst.id,
			GL_TEXTURE_2D,
			0, 0, 0, 0,

			src.width,
			src.height,
			1
		);
	}

	mesh_bunny := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh_bunny);
	mesh_rect := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_rect);

	shader_glass := make_shader_vf(SRC_VERT_MINIMUM, SRC_FRAG_GLASS); defer clear_shader(*shader_glass);
	shader_s := make_shader_vf(SRC_VERT_SCREEN, SRC_FRAG_SCREEN); defer clear_shader(*shader_s);

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

		{
			for Draw_To_Framebuffer.{buffer = *glass_buffer_0, background = .{}} {
				glDepthMask(GL_TRUE);
				glEnable(GL_DEPTH_TEST);
				for *shader_glass {
					set("u_first_pass", cast(s32)1);
					set("u_m", mat_m);
					set("u_vp", mat_vp);
					draw(mesh_bunny);
				}
			}
			for i : 0..3 {
				copy_content(*(glass_buffer_1.tex_color), glass_buffer_0.tex_color);
				copy_content(*(glass_buffer_1.tex_alpha), glass_buffer_0.tex_alpha);
				for Draw_To_Framebuffer.{buffer = *glass_buffer_1, clear_color = false} {
					glDepthMask(GL_TRUE);
					glEnable(GL_DEPTH_TEST);
					for *shader_glass {
						bind(glass_buffer_0.tex_depth, 0);
						bind(glass_buffer_0.tex_color, 1);
						bind(glass_buffer_0.tex_alpha, 2);

						set("u_first_pass", cast(s32)0);
						set("u_m", mat_m);
						set("u_vp", mat_vp);
						draw(mesh_bunny);
					}
				}
				glass_buffer_0, glass_buffer_1 = glass_buffer_1, glass_buffer_0;			
			}			
		}

		for Draw_To_Framebuffer.{window = *window, background = Vector4.{0, 0, 1, 1}} {
			glEnable(GL_BLEND); defer glDisable(GL_BLEND);
			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			for *shader_s {
				bind(glass_buffer_0.tex_color, 0);
				bind(glass_buffer_0.tex_alpha, 1);
				draw(mesh_rect);
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

SRC_VERT_SCREEN :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec2 a_uv;

	out vec2 uv;

	void main() {
		uv = a_uv;
		gl_Position = vec4(a_pos, 1);
	}
GLSL
SRC_FRAG_SCREEN :: #string GLSL
	#version 430 core
	layout(binding = 0) uniform sampler2D u_color;
	layout(binding = 1) uniform sampler2D u_alpha;

	in vec2 uv;
	out vec4 o_color;

	void main() {
		vec3 col = texture(u_color, uv).xyz;
		float alpha = texture(u_alpha, uv).x;
		o_color = vec4(col, alpha);
	}
GLSL
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
SRC_FRAG_GLASS :: #string GLSL
	#version 430 core
	layout(binding = 0) uniform sampler2D u_depth;
	layout(binding = 1) uniform sampler2D u_color;
	layout(binding = 2) uniform sampler2D u_alpha;

	uniform int u_first_pass;
	uniform float u_time;

	in struct Vert_Out {
		vec3 pos;
		vec3 norm;
	} vert_out;

	layout(location = 0) out vec4 o_color[2];

	void main() {
		vec2 uv; 
		if(u_first_pass == 0) {
			uv = gl_FragCoord.xy / textureSize(u_depth, 0);
			float d0 = texture(u_depth, uv).x;
			float d1 = gl_FragCoord.z;
			if(d1 <= d0) {
				discard;
			}
		}

		float brightness = min(1, max(dot(normalize(vert_out.norm), vec3(1, 0, 0)), 0) + .3);

		ivec3 ipos = ivec3(floor(vert_out.pos * 2));
		vec4 color_this = vec4(
			mod(ipos.x + ipos.y + ipos.z, 2) == 0 ? vec3(1, .5, .5) : vec3(.5, 1, .5),
			.6
		);
		color_this.xyz *= brightness;

		// vec4 color_this = vec4(
		// 	vec3(1),
		// 	.5
		// );

		if(u_first_pass == 0) {
			vec3 color_back = color_this.xyz;
			float alpha_back = color_this.w;
			vec3 color_front = texture(u_color, uv).xyz;
			float alpha_front = texture(u_alpha, uv).x;

			color_this = vec4(
				color_back * alpha_back * (1 - alpha_front) + color_front * alpha_front,
				1 - (1 - alpha_front) * (1 - alpha_back)
			);
			color_this.rgb /= color_this.a;
		}		

		o_color[0] = color_this.rgba;
		o_color[1] = color_this.aaaa;
	}
GLSL