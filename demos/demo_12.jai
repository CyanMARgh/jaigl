#import "gltf_parser";

demo_12 :: () {
	window := create_window(1200, 800, "model loading"); defer close_window(window);
	simp.set_render_target(window);

	mesh_raw_soa, texture_albedo := get_mesh();
	defer clear_mesh_raw(mesh_raw_soa);

	win_state : Win_State;
	camera : Camera = .{position = .{4, 1.5, 5}};

	mesh := make_mesh_soa(mesh_raw_soa);
	defer clear_mesh(mesh);
	defer clear_texture(texture_albedo);
	// shader := make_shader_vf(SRC_VERT, SRC_DRAW_NORMALS_FRAG); defer clear_shader(*shader);
	shader := make_shader_vf(SRC_VERT_MINIMUM, SRC_FRAG_SHOW_MAPS); defer clear_shader(*shader);

	time := current_time_monotonic();
	time0 := time;
	while !win_state.should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := cast(float)(to_milliseconds(new_time - time0) % 1_000_000) / 1000;

		Input.update_window_events();
		move_camera(*camera, xx dt, win_state.pressed_keys);

		for Input.events_this_frame handle_event(*win_state, it);

		simp.clear_render_target(.1, .3, .3, 1);

		glClear(GL_DEPTH_BUFFER_BIT);
		glEnable(GL_DEPTH_TEST);
		glEnable(GL_CULL_FACE);

		mat_v, mat_p := get_transform_v_p(*camera, .{1200, 800});
		mat_vp := mat_p * mat_v;
		factor := 1.;
		mat_m := make_scale_matrix4(.{factor, factor, factor});

		use(shader);
			set(*shader, "u_m", mat_m);
			set(*shader, "u_vp", mat_vp);
			set(*shader, "u_time", current_time);
			bind(texture_albedo, 0);

			// set(*shader, "u_transform_mv", mat_v * mat_m);
			// set(*shader, "u_transform_p", mat_p);
		draw(mesh);

		simp.swap_buffers(window);
		reset_temporary_storage();
        sleep_milliseconds(10);
	}
}
#scope_file

get_mesh :: () -> Mesh_Raw_SOA, albedo:Texture {
	// gltf_data := gltf_parse_file("./res/plane_gltf/plane.glb");
	gltf_data := gltf_parse_file("./res/helmet/DamagedHelmet.gltf");
	gltf_load_buffers(*gltf_data);
	defer gltf_free(*gltf_data);

	primitve := gltf_data.meshes[0].primitives[0];
	material := gltf_data.materials[primitve.material];
	base_color_texture := gltf_data.textures[material.metallic_roughness.base_color_texture.index];
	base_color_image := gltf_data.images[base_color_texture.source];

	texture_albedo := load_texture(tprint("res/helmet/%", base_color_image.uri));

	print("%\n", base_color_image);

	vertices : [..]float;
	normals : [..]float;
	uvs : [..]float;
	indices : [..]u32;

	{
		if primitve.position_accessor != -1 {
			accessor := gltf_data.accessors[primitve.position_accessor];
			print("coords accessor = %\n", accessor);
			read_buffer_from_accessor(*gltf_data, accessor, *vertices);
		}
		if primitve.normal_accessor != -1 {
			accessor := gltf_data.accessors[primitve.normal_accessor];
			print("uv normal accessor: %\n", accessor);
			read_buffer_from_accessor(*gltf_data, accessor, *normals);
		}
		if primitve.texcoord_0_accessor != -1 {
			accessor := gltf_data.accessors[primitve.texcoord_0_accessor];
			print("uv coords accessor: %\n", accessor);
			read_buffer_from_accessor(*gltf_data, accessor, *uvs);			
		}
		accessor := gltf_data.accessors[primitve.indices_accessor];
		print("ids accessor = %\n", accessor);
		read_buffer_from_accessor(*gltf_data, accessor, *indices);		
	}
	vertices3 : []Vector3;
	vertices3.count = vertices.count / 3;
	vertices3.data = xx vertices.data;

	normals3 : []Vector3;
	normals3.count = normals.count / 3;
	normals3.data = xx normals.data;

	uvs2 : []Vector2;
	uvs2.count = uvs.count / 2;
	uvs2.data = xx uvs.data;
	// for uvs2 print("%\n", it);

	print("ok\n");
	return .{
		points = vertices3,
		indices = indices,
		normals = normals3,
		uvs = uvs2,
		most_general = .UVN,
		gl_ready = true
	}, texture_albedo;
}

SRC_VERT_MINIMUM :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec2 a_uv;
	layout (location = 2) in vec3 a_norm;

	uniform mat4 u_vp;
	uniform mat4 u_m;

	out struct Vert_Out {
		vec3 pos;
		vec2 uv;
		vec3 norm;
	} vert_out;

	void main() {
		vec4 p = u_m * vec4(a_pos, 1);
		vert_out.pos = p.xyz;
		vert_out.norm = a_norm;
		vert_out.uv = a_uv;
		gl_Position = u_vp * p;
	}
GLSL
SRC_FRAG_SHOW_MAPS :: #string GLSL
	#version 430 core
	layout(binding = 0) uniform sampler2D u_color;

	in struct Vert_Out {
		vec3 pos;
		vec2 uv;
		vec3 norm;
	} vert_out;

	out vec4 o_color;
	uniform float u_time;


	void main() {
		float f = fract(u_time * .400);
		vec3 color = 
			f < .5 ?
				vec3(vert_out.uv.x, vert_out.uv.y - 1, 0)
			:
				texture(u_color, vert_out.uv).rgb
			;

		o_color = vec4(color, 1);
	}
GLSL