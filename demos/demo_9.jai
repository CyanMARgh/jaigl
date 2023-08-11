demo_9 :: () {
	sigma_low, sigma_high : int = 2, 4;
	beta, threshold := 1.0, .5;

	params : []Any = .[*sigma_low, *sigma_high, *beta, *threshold];
	params_list := Param_List.{params, "res/demo9_options.txt"};
	{
		res := refresh_params(params_list);
		if res != .OK print("result = %\n", res);
	}

	WIDTH, HEIGHT :: 1200, 800;

	window := create_window(WIDTH, HEIGHT, "filters"); defer close_window(window);
	__active_window = window;
	win_state : Win_State;
	simp.set_render_target(window);

	mesh_rect := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_rect);

	// mesh := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh);
	shader_final := make_shader_vf(SRC_FINAL_VERT, SRC_FINAL_FRAG); defer clear_shader(*shader_final);
	shader_grayscale := make_shader_c(SRC_GRAYSCALE_COMP); defer clear_shader(*shader_grayscale);
	shader_gauss_x := make_shader_c(SRC_GAUSS_COMP); defer clear_shader(*shader_gauss_x);
	shader_gauss_y := make_shader_c(SRC_GAUSS_COMP, flags = .["SECOND"]); defer clear_shader(*shader_gauss_y);
	shader_copy_r32f := make_shader_c(SRC_COPY_R32F_COMP); defer clear_shader(*shader_copy_r32f);
	shader_dog := make_shader_c(SRC_DOG_COMP); defer clear_shader(*shader_dog);
	shader_kuwahara := make_shader_c(SRC_KUWAHARA_COMP); defer clear_shader(*shader_kuwahara);

	texture_input := load_texture("res/input_texture.png"); defer clear_texture(texture_input);
	// texture_buf0 := make_storage(WIDTH, HEIGHT, GL_R32F);
	// texture_buf1 := make_storage(WIDTH, HEIGHT, GL_R32F);
	// texture_buf2 := make_storage(WIDTH, HEIGHT, GL_R32F);
	texture_kuwahara := make_storage(WIDTH, HEIGHT, GL_RGBA32F);

	// buf_negative := make_image(WIDTH, HEIGHT, GL_RGB32F);

	apply_gauss :: (texture : Texture, buf : Texture, total_level : int) #expand {
		assert(texture.width == buf.width && texture.height == buf.height);
		bind_as_storage(texture, 0);
		bind_as_storage(buf, 1);
		while total_level > 0 {
			blur_lvl := cast(s32)min(total_level, 3); total_level -= 3;
			use(shader_gauss_x);
				set(*shader_gauss_x, "blur_lvl", blur_lvl);
			compute(shader_gauss_x, texture.width, texture.height);
			use(shader_gauss_y);
				set(*shader_gauss_y, "blur_lvl", blur_lvl);
			compute(shader_gauss_y, texture.width, texture.height);
		}
	}

	apply_filter :: () #expand {
		use(shader_kuwahara);
			bind_as_storage(texture_input, 0);
			bind_as_storage(texture_kuwahara, 1);				
		compute(shader_kuwahara, xx WIDTH, xx HEIGHT);
		// use(shader_grayscale);
		// 	bind_as_storage(texture_input, 0);
		// 	bind_as_storage(texture_buf0, 1);	
		// compute(shader_grayscale, xx WIDTH, xx HEIGHT);

		// apply_gauss(texture_buf0, texture_buf1, sigma_low);
		// use(shader_copy_r32f);
		// 	bind_as_storage(texture_buf0, 0);
		// 	bind_as_storage(texture_buf2, 1);
		// compute(shader_copy_r32f, xx WIDTH, xx HEIGHT, 1);

		// apply_gauss(texture_buf2, texture_buf1, sigma_high - sigma_low);

		// use(shader_dog);
		// 	set(*shader_dog, "beta", beta);
		// 	set(*shader_dog, "threshold", threshold);
		// 	bind_as_storage(texture_buf0, 0);
		// 	bind_as_storage(texture_buf2, 1);
		// compute(shader_dog, xx WIDTH, xx HEIGHT, 1);		
	}	
	apply_filter();

	while !win_state.should_exit {
		Input.update_window_events();
		for Input.events_this_frame handle_event(*win_state, it);
		if win_state.pressed_keys[#char"R"] {
			res := refresh_params(params_list);
			if res != .OK print("result = %\n", res);
			apply_filter();
		}

		simp.clear_render_target(.1, .3, .3, 1);

		glClear(GL_DEPTH_BUFFER_BIT);

		use(shader_final);
			bind(texture_kuwahara, 0);
		draw(mesh_rect);
		check_gl_error();

		simp.swap_buffers(window);
		reset_temporary_storage();
        sleep_milliseconds(10);
	}
}
#scope_file

#import "File";
Param_List :: struct {
	refs : []Any;
	src_path : string;
}
refresh_params :: (using params_list : Param_List) -> enum u8 { OK; INVALID_TYPE; UNABLE_TO_OPEN; CANT_PARSE; } {
	src, ok := read_entire_file(src_path); defer free(src);
	view := src;
	if !ok return .UNABLE_TO_OPEN;
	for refs {
		if <<cast(*Type)(*(it.type)) == {
			case *int;
				(cast(**int)it.value_pointer).*.*, ok = parse_int(*view, spaces = DEFAULT_SPACES);
			case *float;
				(cast(**float)it.value_pointer).*.*, ok = parse_float(*view);
			case;
			assert(false);
		}
	}
	return ifx ok then .OK else .CANT_PARSE;
}
// Mesh_Raw_SOA :: struct {
// 	points  : []vec3;
// 	uvs     : []vec2;
// 	normals : []vec3;
// 	union {
// 		faces : []Face;
// 		indices : []u32;
// 	}
// 	most_general := Ftype.INVALID;
// 	gl_ready := false;
// }
// make_sphere :: (arcs : int, rows : int, radius := 1.0, offset := vec3.{}) -> Mesh_Raw_SOA {
// 	assert(rows >= 1 && arcs >= 3);
// 	using mesh : Mesh_Raw_SOA;
// 	points = NewArray((rows + 1) * arcs, vec3);
// 	uvs = NewArray((rows + 1) * arcs, Vector2);
// 	normals = NewArray((rows + 1) * arcs, vec3);
// 	indices = NewArray(6 * rows * arcs, u32);
// 	gl_ready = true;

// 	for i : 0..rows {
// 		phi := PI * i / rows;
// 		for j : 0..arcs-1 {
// 			theta := 2 * PI * i / arcs;
// 			dir := vec3.{sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta)}; 

// 			normals[arcs * i + j] = dir;
// 			points[arcs * i + j] = dir * radius + offset;
// 			uvs[arcs * i + j] = .{theta / (2 * PI), phi / PI};
// 		}
// 	}

// 	k := 0;
// 	for j : 0..arcs-1 {
// 		indices[k], indices[k + 1], indices[k + 2] = j, arcs + (j + 1) % arcs, arcs + j;
// 		k += 3;
// 	}

// 	// k := 0;
// 	// for i : 0..rows-2 {
// 	// 	for j : 0..arcs-1 {
// 	// 		indices[k], indices[k + 1], indices[k + 2] = 

// 	// 		k += 3;
// 	// 	}
// 	// }
// }

SRC_KUWAHARA_COMP :: #string GLSL
	#version 430 core

	layout(rgba32f, binding = 0) uniform image2D tex_in;
	layout(rgba32f, binding = 1) uniform image2D tex_out;
	uniform float beta = 5;
	uniform float threshold = .5;

	const int R = 9;

	float length2(vec2 v) {
		return v.x * v.x + v.y * v.y;
	}
	ivec2 p0;

	const float PI = 3.14159265;

	#define DIRS 8
	float weight(ivec2 v, int region) {
		float alpha = (PI * region) / 4, beta = (PI * (region + 1)) / 4;
		float phi = mod(atan(v.x, v.y) + PI * (9. / 8), 2 * PI);
		if(phi < alpha || phi > beta) return 0;

		return exp(-.05 * length2(v));
	}

	float D[DIRS];
	vec3 M[DIRS];
	void find_mean_and_deviation() {
		vec3 M2[DIRS];
		float P[DIRS];

		for(int i = 0; i < DIRS; i++) {
			D[i] = 0;
			M[i] = vec3(0);
			M2[i] = vec3(0);
			P[i] = 0;
		}

		ivec2 v;
		for(v.y = -R; v.y <= R; v.y++) {
			for(v.x = -R; v.x <= R; v.x++) {
				vec3 c = imageLoad(tex_in, p0 + v).xyz;
				for(int i = 0; i < DIRS; i++) {
					float p = weight(v, i);
	
					M[i] += c * p;
					M2[i] += c * c * p;
					P[i] += p;
				}
			}
		}
		for(int i = 0; i < DIRS; i++) {
			M[i] /= P[i]; M2[i] /= P[i];
			D[i] = pow(abs(dot(M2[i] - M[i] * M[i], vec3(1))), .3);
		}
	}

	void main() {
		p0 = ivec2(gl_GlobalInvocationID.xy);

		find_mean_and_deviation();

		vec3 result = vec3(0);
		// float W = 0;
		// for(int i = 0; i < DIRS; i++) {
		// 	float w = 1. / (.0001 + D[i]);
		// 	result += M[i] * w;
		// 	W += w;
		// }
		// result /= W;

		float smallesd_deviation = 10000;
		for(int i = 0; i < DIRS; i++) {
			if(D[i] < smallesd_deviation) {
				result = M[i];
				smallesd_deviation = D[i];
			}
		}

		imageStore(tex_out, p0, vec4(result, 1));
	}
GLSL
SRC_DOG_COMP :: #string GLSL
	#version 430 core

	layout(r32f, binding = 0) uniform image2D buf0;
	layout(r32f, binding = 1) uniform image2D buf1;
	uniform float beta = 5;
	uniform float threshold = .5;

	void main() {
		ivec2 p0 = ivec2(gl_GlobalInvocationID.xy);
		float r0 = imageLoad(buf0, p0).x;
		float r1 = imageLoad(buf1, p0).x;

		float m = (r0 * (1 + beta) - r1 * beta) > threshold ? 1 : 0;

		// imageStore(buf0, p0, vec4(r0 * (1 + beta) - r1 * beta));
		imageStore(buf0, p0, vec4(p0.x < 600 ? m : r0));
	}
GLSL
SRC_GAUSS_COMP :: #string GLSL
	#version 430 core

	layout(r32f, binding = 0) uniform volatile image2D buf0;
	layout(r32f, binding = 1) uniform volatile image2D buf1;

	uniform int blur_lvl = -1;

	ivec2 p0;
	float at(int i) {
		#ifdef SECOND
		return imageLoad(buf1, p0 + ivec2(0, i)).x;
		#else
		return imageLoad(buf0, p0 + ivec2(i, 0)).x;
		#endif
	}
	float blur7() {
		float pascal[7] = float[7](1, 6, 15, 20, 15, 6, 1);
		float sum = 0;
		for(int i = -3; i <= 3; i++) {
			sum += pascal[i + 3] * at(i);
		}
		return sum / 64;
	}
	float blur5() {
		float pascal[5] = float[5](1, 4, 6, 4, 1);
		float sum = 0;
		for(int i = -2; i <= 2; i++) {
			sum += pascal[i + 2] * at(i);
		}
		return sum / 16;
	}
	float blur3() {
		float pascal[3] = float[3](1, 2, 1);
		float sum = 0;
		for(int i = -1; i <= 1; i++) {
			sum += pascal[i + 1] * at(i);
		}
		return sum / 4;
	}

	void main() {
		p0 = ivec2(gl_GlobalInvocationID.xy);

		float result;
		if(blur_lvl == 1) {
			result = blur3();
		} else if(blur_lvl == 2) {
			result = blur5();
		} else if(blur_lvl == 3) {
			result = blur7();
		}
		imageStore(
			#ifdef SECOND
			buf0
			#else
			buf1
			#endif
		, p0, vec4(result));
	}
GLSL
SRC_GRAYSCALE_COMP :: #string GLSL
	#version 430 core

	layout(rgba32f, binding = 0) uniform image2D in_tex;
	layout(r32f, binding = 1) uniform image2D out_tex;

	const vec3 bmap = vec3(0.2126, 0.7152, 0.0722);

	void main() {
		ivec2 p0 = ivec2(gl_GlobalInvocationID.xy);
		vec3 col3 = imageLoad(in_tex, p0).xyz;
		imageStore(out_tex, p0, vec4(dot(bmap, col3)));
	}
GLSL
SRC_COPY_R32F_COMP :: #string GLSL
	#version 430 core

	layout(r32f, binding = 0) uniform image2D in_tex;
	layout(r32f, binding = 1) uniform image2D out_tex;

	void main() {
		ivec2 p0 = ivec2(gl_GlobalInvocationID.xy);
		imageStore(out_tex, p0, imageLoad(in_tex, p0));
	}
GLSL
SRC_FINAL_VERT :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec2 a_uv;

	out struct Vert_Out {
		vec2 uv;
	} vert_out;

	void main() {
		vert_out.uv = a_uv;
		gl_Position = vec4(a_pos, 1);
	}
GLSL
SRC_FINAL_FRAG :: #string GLSL
	#version 430 core

	layout(binding = 0) uniform sampler2D u_tex_in;

	in struct Vert_Out {
		vec2 uv;
	} vert_out;

	out vec4 o_color;

	vec2 flip(vec2 uv) {
		return vec2(uv.x, 1 - uv.y);
		// return uv;
	}
	void main() {	
		vec2 uv = flip(vert_out.uv);
		o_color = vec4(texture(u_tex_in, uv).rgb, 1);
	}
GLSL
