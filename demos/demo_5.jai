demo_5 :: () {
	width, height : s32 = 1200, 800;
	window := create_window(width, height, "sky"); defer close_window(window);
	__active_window = window;
	win_state : Win_State;
	simp.set_render_target(window);
	camera : Camera = .{position = .{0, 8, 0}, pitch = 0, yaw = 3};

	// shader := make_shader_vgf(SRC_PARTICLE_VERT, SRC_PARTICLE_GEOM, SRC_PARTICLE_FRAG); defer clear_shader(*shader);
	mesh_rect := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_rect);
	empty_mesh := get_empty_mesh(); defer clear(*empty_mesh);
	check_gl_error();

	// shader_water := make_shader_vf(SRC_VERT_WATER, SRC_FRAG_SIMPLE_COLOR_LIGHTING); defer clear_shader(*shader_water);
	shader_skybox := make_shader_vf(SRC_VERT_SCREEN_CUBE, SRC_FRAG_SCREEN_CUBE); defer clear_shader(*shader_skybox);
	main_buffer := make_frame_buffer(xx width, xx height, add_alpha = true); defer clear_frame_buffer(*main_buffer);

	// shader_screen_rectangle := make_shader_vf(SRC_VERT_SCREEN_CUBE, SRC_FRAG_SCREEN_RECT); defer clear_shader(*shader_screen_rectangle);

	shader_sphere := make_shader_vf(SRC_VERT_SPHERE, SRC_FRAG_SIMPLE_COLOR_LIGHTING); defer clear_shader(*shader_sphere);
	shader_torus := make_shader_vf(SRC_VERT_TORUS, SRC_FRAG_SIMPLE_COLOR_LIGHTING); defer clear_shader(*shader_torus);
	shader_plane := make_shader_vf(SRC_VERT_DETAILED_PLANE, SRC_FRAG_SIMPLE_COLOR_LIGHTING); defer clear_shader(*shader_plane);
	shader_water := make_shader_vf(SRC_VERT_WATER, SRC_FRAG_WATER); defer clear_shader(*shader_water);
	shader_fog_pass := make_shader_vf(SRC_VERT_SCREEN_SPACE, SRC_FRAG_FOG_PASS); defer clear_shader(*shader_fog_pass);

	RENDER_VIDEO :: false;

	#if RENDER_VIDEO {
		ffmpeg := ffmpeg_start_rendering(width, height, filename = "demo_5_10000.mp4", path = "screenshots", bitrate = 10000, length_seconds = 5, fps = 30);
		defer ffmpeg_end_rendering(*ffmpeg);		
	} else {	
		time := current_time_monotonic();
		time0 := time;
	}

	// TODO uniform block
	Scene_Light :: struct {
		sun_direction : Vector4;
		sky_color_0 : Vector4;
		sky_color_1 : Vector4;
		sky_color_2 : Vector4;
	}
	scene_light : Scene_Light;

	// glEnable(GL_CULL_FACE);
	// TODO single texture for color and alpha

	while !win_state.should_exit {
		#if RENDER_VIDEO {
			dt := ffmpeg.dt;
			current_time := ffmpeg.time;			
		} else {
			new_time := current_time_monotonic();
			dt := to_float64_seconds(new_time - time); time = new_time;
			current_time := to_float64_seconds(new_time - time0);			
		}

		Input.update_window_events();
		for Input.events_this_frame handle_event(*win_state, it);
		move_camera(*camera, xx dt, win_state.pressed_keys, 10);

		mat_v, mat_p := get_transform_v_p(camera, .{xx width, xx height});
		mat_rp := get_trandform_rp(camera, .{xx width, xx height});
		mat_vp := mat_p * mat_v;

		// simp.clear_render_target(0, 0, 0, 1);
		// glClear(GL_DEPTH_BUFFER_BIT);
		//TODO

		sun_direction := Vector3.{xx sin(.1 * current_time), xx cos(.1 * current_time), 0};

		for Draw_To_Framebuffer.{buffer = *main_buffer, background = .{0, 0, 0, 0}} 
		{
			// if false
			{
				GRID_WIDTH :u32: 200;
				GRID_HEIGHT :u32: 1500;
				glEnable(GL_DEPTH_TEST); defer glDisable(GL_DEPTH_TEST);
				use(shader_water);
					set(*shader_water, "u_mat_m", make_scale_matrix4(.{5, 5, 5}));
					set(*shader_water, "u_mat_vp", mat_vp);
					set(*shader_water, "u_grid_width", GRID_WIDTH);
					set(*shader_water, "u_grid_height", GRID_HEIGHT);
					set(*shader_water, "u_eye", camera.position);
					set(*shader_water, "u_time", cast(float)current_time);
					set(*shader_water, "u_color", Vector3.{.4, .5, .8});
					set(*shader_water, "u_sun_direction", sun_direction);
				draw(empty_mesh, GRID_WIDTH * GRID_HEIGHT * 6);
			}			
		}

		for Draw_To_Framebuffer.{window = *window} 
		{
			glClearColor(0, 0, 0, 0);
			{
				use(shader_skybox);
					set(*shader_skybox, "u_mat_rp", mat_rp);
					set(*shader_skybox, "u_time", cast(float)current_time);
					set(*shader_skybox, "u_sun_direction", sun_direction);
				draw(empty_mesh, 36);
			}
			{
				glEnable(GL_BLEND); defer glDisable(GL_BLEND);
				glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
				use(shader_fog_pass);
					bind(main_buffer.tex_color, 0);
					bind(main_buffer.tex_depth, 1);
					bind(main_buffer.tex_alpha, 2);
				draw(empty_mesh, 6);
			}
		}

		simp.swap_buffers(window);
		reset_temporary_storage();

		#if RENDER_VIDEO {
			ffmpeg_add_screenshot(*ffmpeg);
			if ffmpeg.ended break;
		} else {
			sleep_milliseconds(10);	
		}
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
		// glClearColor(0, 0, 0, 0);
		// glClear(GL_COLOR_BUFFER_BIT);
		simp.clear_render_target(background.x, background.y, background.z, background.w);
	}
	#insert body;
}

#import "Random";

WAVES :: 40;
WAVE_PROPERTIES :: #run () -> string {
	// array_builder := String_Builder.{allocator = temp};
	// append(*array_builder, "{\n");
	// for i : 0..WAVES-1 {
	// 	phi := random_get_within_range(0, PI * 2);
	// 	factor := random_get_within_range(.5, 2);
	// 	print_to_builder(*array_builder, "\tvec2(%, %)%", sin(phi) * factor, cos(phi) * factor, ifx i < WAVES-1 then ",\n" else "\n};\n");
	// }
	GENERATOR :: #string GLSL
		const int ITERATIONS_NORMAL = 40;
		const int ITERATIONS_HEIGHT = 20;
		const float DRAG_MULT = 0.28;
		const float WAVE_HEIGHT = .5;

		vec2 wavedx(vec2 position, vec2 direction, float frequency, float timeshift) {
			float x = dot(direction, position) * frequency + timeshift;
			float wave = exp(sin(x) - 1.0);
			float dx = wave * cos(x);
			return vec2(wave, -dx);
		}
		float get_wave_height(vec2 position, int iterations) {
			float iter = 0.0; // this will help generating well distributed wave directions
			float frequency = 1.0; // frequency of the wave, this will change every iteration
			float timeMultiplier = 1.0; // time multiplier for the wave, this will change every iteration
			float weight = 1.0;// weight in final sum for the wave, this will change every iteration
			float sumOfValues = 0.0; // will store final sum of values
			float sumOfWeights = 0.0; // will store final sum of weights
			for(int i=0; i < iterations; i++) {
				// generate some wave direction that looks kind of random
				vec2 p = vec2(sin(iter), cos(iter));
				// calculate wave data
				vec2 res = wavedx(position, p, frequency, u_time * timeMultiplier);

				// shift position around according to wave drag and derivative of the wave
				position += p * res.y * weight * DRAG_MULT;

				// add the results to sums
				sumOfValues += res.x * weight;
				sumOfWeights += weight;

				// modify next octave parameters
				weight *= 0.82;
				frequency *= 1.18;
				timeMultiplier *= 1.07;

				// add some kind of random value to make next wave look random too
				iter += 1232.399963;
			}
			// calculate and return
			return sumOfValues / sumOfWeights;
		}
		vec3 get_wave_normal(vec2 pos, float e, float depth) {
			vec2 ex = vec2(e, 0);
			float H = get_wave_height(pos.xy, ITERATIONS_NORMAL) * depth;
			vec3 a = vec3(pos.x, H, pos.y);
			return normalize(
				cross(
					a - vec3(pos.x - e, get_wave_height(pos.xy - ex.xy, ITERATIONS_NORMAL) * depth, pos.y), 
					a - vec3(pos.x, get_wave_height(pos.xy + ex.yx, ITERATIONS_NORMAL) * depth, pos.y + e)
				)
			);
		}
	GLSL
	// result := tprint("const uint DIR_COUNT = %1;\nvec2 directions[%1] = %2\n%3", WAVES, builder_to_string(*array_builder), GENERATOR);
	// print("%", result);
	return GENERATOR;
}();
SRC_VERT_WATER :: #run tprint(#string GLSL
	#version 430 core

	const float PI = 3.14159265;
	uniform float u_time;
	uniform mat4 u_mat_m;
	uniform mat4 u_mat_vp;

	uniform uint u_grid_width;
	uniform uint u_grid_height;
	%1

	out struct Vert_Out {
		vec3 position;
		vec3 normal;
		vec2 uv;
		float h;
	} vert_out;

	vec2 get_coord_v0() {
		uvec2 offsets[6] = uvec2[6](uvec2(0, 1), uvec2(0, 0), uvec2(1, 1), uvec2(0, 0), uvec2(1, 0), uvec2(1, 1));
		uvec2 coord = uvec2((gl_VertexID / 6) %% u_grid_width, gl_VertexID / (6 * u_grid_width)) + offsets[gl_VertexID %% 6];
		return vec2(coord) / vec2(float(u_grid_width), float(u_grid_height));
	}
	vec2 get_coord_v1() {
		return get_coord_v0() * 2 - 1;
	}
	vec2 get_coord_v2() {
		vec2 p0 = get_coord_v0();
		p0.x *= 2 * PI;
		return vec2(sin(p0.x), cos(p0.x)) * (1 / (1 - p0.y * (1. - .5 / u_grid_height)) - 1);
	}

	void main() {
		vec2 pos0 = get_coord_v2();

		float h = get_wave_height(pos0, ITERATIONS_HEIGHT) * WAVE_HEIGHT - WAVE_HEIGHT;
		vec3 N = get_wave_normal(pos0, 0.01, WAVE_HEIGHT); 

		vec4 pos = u_mat_m * vec4(pos0.x, h, pos0.y, 1);
		vert_out.position = pos.xyz;
		vert_out.uv = pos0;
		vert_out.normal = normalize((u_mat_m * vec4(N, 0)).xyz);
		vert_out.h = h;

		gl_Position = u_mat_vp * pos;
	}
GLSL, WAVE_PROPERTIES);
SRC_FRAG_WATER :: #run tprint(#string GLSL
	#version 430 core

	const float PI = 3.14159265;
	uniform vec3 u_eye;
	uniform float u_time;
	uniform mat4 u_mat_m;

	%1

	uniform vec3 u_color = vec3(.7, .3, .2);
	uniform vec3 u_sun_direction = vec3(0, 1, 0);

	in struct Vert_Out {
		vec3 position;
		vec3 normal;
		vec2 uv;
		float h;
	} vert_out;
	// out vec4 o_color;
	layout(location = 0) out vec4 o_color[2];

	void main() {
		vec3 light_dir = u_sun_direction;
		vec3 light_color = vec3(1, 1, 1);
		vec3 position = vert_out.position;

		vec3 normal;
		if(false) {
			normal = normalize(vert_out.normal);
		} else {
			vec3 N = get_wave_normal(vert_out.uv, 0.01, WAVE_HEIGHT); 
			normal = normalize((u_mat_m * vec4(N, 0)).xyz);
		}

		vec3 color = u_color;
		float specular_strength = .5;

		vec3 view_dir = normalize(u_eye - position);
		vec3 reflect_dir = reflect(-light_dir, normal);
		vec3 halfway_dir = normalize(light_dir + view_dir);

		vec3 ambient_light = vec3(.0);
		vec3 diifuse_light = max(dot(normal, light_dir), 0) * light_color;
		vec3 specular_light = specular_strength * pow(max(dot(normal, halfway_dir), 0), 32) * light_color;

		vec3 scattering = vec3(0.0293, 0.0698, 0.1717) * (0.2 + (vert_out.h + WAVE_HEIGHT) / WAVE_HEIGHT);
		// vec3 scattering = vec3(position.y);

		float fresnel = (0.04 + (1.0-0.04)*(pow(1.0 - max(0.0, dot(normal, view_dir)), 5.0)));

		vec3 result_color = mix(scattering, specular_light, fresnel) * 2; 

		o_color[0] = vec4(result_color, 1);
		o_color[1] = vec4(exp(-0.001 * length(position.xz)));
	}
GLSL, WAVE_PROPERTIES);

SRC_VERT_SPHERE :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	const float PI = 3.14159265;
	uniform uint u_rows;
	uniform uint u_columns;
	uniform mat4 u_mat_m;
	uniform mat4 u_mat_vp;

	out struct Vert_Out {
		vec3 position;
		vec3 normal;
	} vert_out;

	void main() {
		uint subid = gl_VertexID % 6;
		uint quad_column = (gl_VertexID / 6) % u_columns;
		uint quad_row = gl_VertexID / (6 * u_columns);
		uint offsets[12] = uint[12](
			0, 1,
			0, 0,
			1, 1,
			0, 1,
			1, 1,
			1, 2
		);
		uint row = quad_row + offsets[subid << 1];
		uint column = quad_column + offsets[(subid << 1) | 1];

		float yaw = 2 * PI * float(column) / float(u_columns);
		float pitch = PI * float(row) / float(u_rows);

		vec3 pos0 = vec3(sin(yaw) * sin(pitch), cos(pitch), cos(yaw) * sin(pitch));
		vec4 pos = u_mat_m * vec4(pos0, 1);

		gl_Position = u_mat_vp * pos;
		vert_out.position = pos.xyz;
		vert_out.normal = (u_mat_m * vec4(pos0, 0)).xyz;
	}
GLSL
SRC_VERT_TORUS :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	const float PI = 3.14159265;

	uniform uint u_rows = 50;
	uniform uint u_columns = 10;
	const float u_R = 1., u_r = .2;   

	uniform mat4 u_mat_m;
	uniform mat4 u_mat_vp;

	out struct Vert_Out {
		vec3 position;
		vec3 normal;
	} vert_out;

	void main() {
		uint subid = gl_VertexID % 6;
		uint quad_column = (gl_VertexID / 6) % u_columns;
		uint quad_row = gl_VertexID / (6 * u_columns);
		uint offsets[12] = uint[12](
			0, 1,
			0, 0,
			1, 1,
			0, 0,
			1, 0,
			1, 1
		);
		uint row = quad_row + offsets[subid << 1];
		uint column = quad_column + offsets[(subid << 1) | 1];

		float phi_0 = 2 * PI * float(column) / float(u_columns);
		float phi_1 = 2 * PI * float(row) / float(u_rows);

		vec2 P0 = vec2(sin(phi_0), cos(phi_0));
		vec2 P1 = vec2(sin(phi_1), cos(phi_1));

		vec3 offset = vec3(P0.y * P1.x, P0.x, P0.y * P1.y) * u_r;  
		vec3 pos0 = vec3(P1.x, 0, P1.y) * u_R + offset;

		vec4 pos = u_mat_m * vec4(pos0, 1);

		gl_Position = u_mat_vp * pos;
		vert_out.position = pos.xyz;
		vert_out.normal = (u_mat_m * vec4(offset, 0)).xyz;
	}
GLSL

SRC_VERT_DETAILED_PLANE :: #string GLSL
	#version 430 core

	uniform uint u_grid_density;
	uniform mat4 u_mat_m;
	uniform mat4 u_mat_vp;

	out struct Vert_Out {
		vec3 position;
		vec3 normal;
	} vert_out;

	void main() {
		uvec2 offsets[6] = uvec2[6](uvec2(0, 1), uvec2(0, 0), uvec2(1, 1), uvec2(0, 0), uvec2(1, 0), uvec2(1, 1));
		uvec2 coord = uvec2((gl_VertexID / 6) % u_grid_density, gl_VertexID / (6 * u_grid_density)) + offsets[gl_VertexID % 6];

		vec2 pos0 = vec2(coord) / vec2(float(u_grid_density)) * 2 - 1;

		vec4 pos = u_mat_m * vec4(pos0.x, 0, pos0.y, 1);
		vert_out.position = pos.xyz;
		vert_out.normal = (u_mat_m * vec4(0, 1, 0, 0)).xyz;

		gl_Position = u_mat_vp * pos;
	}
GLSL
_SRC_VERT_DETAILED_PLANE :: #string GLSL
	#version 430 core

	uniform uint u_grid_density;
	uniform mat4 u_mat_m;
	uniform mat4 u_mat_vp;

	out struct Vert_Out {
		vec3 position;
		vec3 normal;
	} vert_out;

	vec3 heightmap(vec2 p) {
		vec2 direction = vec2(2.11, 3.34);
		float tau = dot(direction, p);
		float h = sin(tau);
		vec2 g = cos(tau) * direction;
		return vec3(h, g.xy);
	}

	void main() {
		uvec2 offsets[6] = uvec2[6](uvec2(0, 1), uvec2(0, 0), uvec2(1, 1), uvec2(0, 0), uvec2(1, 0), uvec2(1, 1));
		uvec2 coord = uvec2((gl_VertexID / 6) % u_grid_density, gl_VertexID / (6 * u_grid_density)) + offsets[gl_VertexID % 6];

		vec2 pos0 = vec2(coord) / vec2(float(u_grid_density)) * 2 - 1;
		vec3 hm = heightmap(pos0) * .2;

		vec4 pos = u_mat_m * vec4(pos0.x, hm.x, pos0.y, 1);
		vert_out.position = pos.xyz;
		vert_out.normal = (u_mat_m * vec4(-hm.y, 1, -hm.z, 0)).xyz;

		gl_Position = u_mat_vp * pos;
	}
GLSL

SRC_FRAG_SIMPLE_COLOR_LIGHTING :: #string GLSL
	#version 430 core

	uniform vec3 u_eye;
	uniform float u_time;

	uniform vec3 u_color = vec3(.7, .3, .2);

	in struct Vert_Out {
		vec3 position;
		vec3 normal;
	} vert_out;
	out vec4 o_color;

	void main() {
		vec3 light_dir = normalize(vec3(0, .2, .8));
		vec3 light_color = vec3(1, 1, 1);
		vec3 normal = normalize(vert_out.normal);
		vec3 color = u_color;
		float specular_strength = .5;

		vec3 view_dir = normalize(u_eye - vert_out.position);
		vec3 reflect_dir = reflect(-light_dir, normal);
		vec3 halfway_dir = normalize(light_dir + view_dir);

		vec3 ambient_light = vec3(.0);
		vec3 diifuse_light = max(dot(normal, light_dir), 0) * light_color;
		vec3 specular_light = specular_strength * pow(max(dot(normal, halfway_dir), 0), 16) * light_color;

		vec3 result_color = (ambient_light + diifuse_light) * color + specular_light;

		// if(fract(u_time) < .5) {
		// 	o_color = vec4(max(result_color.x, max(result_color.y, result_color.z)) > 1 ? vec3(1) : vec3(0), 1);
		// } else {
			o_color = vec4(result_color, 1);
		// }
	}
GLSL

SRC_VERT_SKYBOX :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;

	out struct Vert_Out {
		vec3 position;
	} vert_out;

	void main() {
		vert_out.position = a_pos;
		gl_Position = vec4(a_pos, 1);
	}
GLSL
SRC_FRAG_SKYBOX :: #string GLSL
	#version 430 core

	uniform mat4 u_vp;
	uniform float u_width_over_height;
	uniform float u_fov_vertical;

	in struct Vert_Out {
		vec3 position;
	} vert_out;

	out vec4 o_color;

	void main() {
		// vec3 light_dir = normalize(vec3(0, .2, .8));

		vec2 dir2 = vert_out.position.xyz;
		// vec3 dir = vec3(dir2, 1);
		// vec3 eye_dir = (inverse(u_vp) * vec4(dir, 1)).xyz;
		// eye_dir = normalize(eye_dir);


		// float l = length(eye_dir - light_dir);
		// float brightness = 1 / (.1 + l * 30);

		// vec3 color_base = mix(vec3(.8, .8, 1), vec3(.5, .55, 1), max(dot(vec3(0, 1, 0), eye_dir), 0));

		// o_color = vec4(color_base + vec3(.7, .7, .5) * brightness, 1);
	}
GLSL

SRC_VERT_SCREEN_CUBE :: #string GLSL
	#version 430 core
	uniform mat4 u_mat_rp;
	out vec3 position;
	void main() {
		vec3 points[8] = vec3[8](
			vec3( 1, -1, -1),
			vec3( 1, -1,  1),
			vec3(-1, -1,  1),
			vec3(-1, -1, -1),
			vec3( 1,  1, -1),
			vec3( 1,  1,  1),
			vec3(-1,  1,  1),
			vec3(-1,  1, -1)
		);
		int indices[36] = int[36](
			1, 2, 3, 7, 6, 5,
			4, 5, 1, 5, 6, 2,
			2, 6, 7, 0, 3, 7,
			0, 1, 3, 4, 7, 5,
			0, 4, 1, 1, 5, 2,
			3, 2, 7, 4, 0, 7
		);
		vec3 point = points[indices[gl_VertexID]];
		position = point;
		gl_Position = u_mat_rp * vec4(point, 1);
	}
GLSL
SRC_FRAG_SCREEN_CUBE :: #string GLSL
	#version 430 core
	in vec3 position;
	out vec4 o_color;

	uniform vec3 u_sun_direction = normalize(vec3(0, .3, 1));

	const float PI = 3.14159265;
	const float TAU = 2 * PI;

	const float sun_angular_radius = 0.1;
	const float sun_size = 2 * sin(sun_angular_radius / 2);
	const float sun_height = sin(sun_angular_radius);

	float bump(float xx) {
		return xx > 1 ? 0 : (1 - xx) * (1 - xx);
	}
	vec3 get_sun(vec3 sun_direction, vec3 eye_direction) {
		vec3 diff = (sun_direction - eye_direction) / sun_size;
		float l = dot(diff, diff);
		float brightness = bump(l);

		return vec3(1, .9, .8) * 3 * brightness;
	}
	vec3 gradient(float t, vec3 A, vec3 B, vec3 C, float tb) {
		if(t < 0) return A;
		if(t < tb) return mix(A, B, smoothstep(0, tb, t));
		if(t < 1) return mix(B, C, smoothstep(tb, 1, t));
		return C;
	} 
	float ambient_factor(float h) {
		return smoothstep(-sun_height * 2, sun_height, h);
	}	
	vec3 get_atmosphere(vec3 sun_direction, vec3 eye_direction) {
		float sun_h = sun_direction.y;
		float eye_h = eye_direction.y;
		float brightness = ambient_factor(sun_h);

		vec3 color_day = gradient(eye_h, 
			vec3(224, 243, 252), 
			vec3(195, 213, 230),
			vec3(156, 164, 255), 
			.25
		);
		vec3 color_morning = gradient(eye_h, 
			vec3(200,  77,   0), 
			vec3(255, 230, 173),
			vec3( 80,  91, 213), 
			.05
		);
		vec3 color_by_time = mix(color_morning, color_day, clamp(sun_h / .6, 0., 1.));

		return (color_by_time / 255.) * brightness;
	}
	vec3 get_atmosphere_total(vec3 sun_direction, vec3 eye_direction) {
		vec3 sun = get_sun(sun_direction, eye_direction);
		vec3 atm = get_atmosphere(sun_direction, eye_direction);
		return atm + sun;
	}

	void main() {
		vec3 eye_direction = normalize(position);

		o_color = vec4(get_atmosphere_total(u_sun_direction, eye_direction), 1);
	}
GLSL

SRC_VERT_SCREEN_SPACE :: #string GLSL
	#version 430 core
	out vec2 uv;
	void main() {
		vec2 points[6] = vec2[6](
			vec2(0, 0), vec2(1, 1), vec2(0, 1),
			vec2(0, 0), vec2(1, 0), vec2(1, 1)
		);
		vec2 _uv = points[gl_VertexID];
		uv = _uv;
		gl_Position = vec4(_uv * 2 - 1, 0, 1);
	}
GLSL
SRC_FRAG_FOG_PASS :: #string GLSL
	#version 430 core
	layout(binding = 0) uniform sampler2D u_color;
	layout(binding = 1) uniform sampler2D u_depth;
	layout(binding = 2) uniform sampler2D u_alpha;
	in vec2 uv;
	out vec4 o_color;

	const float z_near = .1, z_far  = 1000;
	float linearize_depth(float depth)  {
		float z = depth * 2 - 1; 
		return (2 * z_near * z_far) / (z_far + z_near - z * (z_far - z_near));	
	}
	void main() {
		vec4 color_base = texture(u_color, uv);
		color_base.a = texture(u_alpha, uv).x;
		o_color = color_base;
		// float depth = texture(u_depth, uv).r;
		// if(depth >= 1) {
		// 	o_color = color_base;
		// 	return;
		// }
		// depth = linearize_depth(depth);
		// o_color = mix(vec4(.8, .8, 1, 1), color_base, exp(-.003 * depth));
	}
GLSL
