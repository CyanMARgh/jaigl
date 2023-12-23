#import "gltf_parser";

demo_12 :: () {
	window := create_window(1200, 800, "gltf tests"); defer close_window(window);
	simp.set_render_target(window);

	mesh_raw_soa, texture_albedo, texture_normal := get_mesh();
	defer clear_mesh_raw(mesh_raw_soa);

	win_state : Win_State;
	camera : Camera = .{position = .{4, 1.5, 5}};

	mesh := make_mesh_soa(mesh_raw_soa);
	defer clear_mesh(mesh);
	defer clear_texture(texture_albedo);
	defer clear_texture(texture_normal);
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
			// set(*shader, "u_time", current_time);
			bind(texture_albedo, 0);
			bind(texture_normal, 1);

			// set(*shader, "u_transform_mv", mat_v * mat_m);
			// set(*shader, "u_transform_p", mat_p);
		draw(mesh);

		simp.swap_buffers(window);
		reset_temporary_storage();
        sleep_milliseconds(10);
	}
}
#scope_file

get_mesh :: () -> Mesh_Raw_SOA, albedo:Texture, normal:Texture {
	gltf_data := gltf_parse_file("./res/helmet/DamagedHelmet.gltf");
	gltf_load_buffers(*gltf_data);
	defer gltf_free(*gltf_data);

	primitve := gltf_data.meshes[0].primitives[0];
	material := gltf_data.materials[primitve.material];

	base_color_texture := gltf_data.textures[material.metallic_roughness.base_color_texture.index];
	normal_texture := gltf_data.textures[material.normal_texture.index];

	base_color_image := gltf_data.images[base_color_texture.source];
	normal_image := gltf_data.images[normal_texture.source];

	texture_albedo := load_texture(tprint("res/helmet/%", base_color_image.uri));
	texture_normal := load_texture(tprint("res/helmet/%", normal_image.uri));

	// print("material = %\n", material);

	vertices : [..]float;
	normals : [..]float;
	uvs : [..]float;
	indices : [..]u32;

	{
		// print("%\n", primitve);
		if primitve.position_accessor != -1 {
			accessor := gltf_data.accessors[primitve.position_accessor];
			// print("coords accessor = %\n", accessor);
			read_buffer_from_accessor(*gltf_data, accessor, *vertices);
		}
		if primitve.normal_accessor != -1 {
			accessor := gltf_data.accessors[primitve.normal_accessor];
			// print("uv normal accessor: %\n", accessor);
			read_buffer_from_accessor(*gltf_data, accessor, *normals);
		}
		if primitve.texcoord_0_accessor != -1 {
			accessor := gltf_data.accessors[primitve.texcoord_0_accessor];
			// print("uv coords accessor: %\n", accessor);
			read_buffer_from_accessor(*gltf_data, accessor, *uvs);			
		}
		accessor := gltf_data.accessors[primitve.indices_accessor];
		// print("ids accessor = %\n", accessor);
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
	assert(vertices3.count == normals3.count && vertices3.count == uvs2.count);
	assert(indices.count % 3 == 0);

	tangents := NewArray(normals3.count, Vector3);
	binormals := NewArray(normals3.count, Vector3);
	{
		for i : 0..indices.count/3-1 {
			i1, i2, i3 := indices[i * 3], indices[i * 3 + 1], indices[i * 3 + 2];
			p1, p2, p3 := vertices3[i1], vertices3[i2], vertices3[i3];
			uv1, uv2, uv3 := uvs2[i1], uvs2[i2], uvs2[i3];

			e1 := p2 - p1;
			e2 := p3 - p1;
			duv1 := uv2 - uv1;
			duv2 := uv3 - uv1;

			f := (duv1.x * duv2.y - duv2.x * duv1.y);

			tangent := normalize(f * Vector3.{
				duv2.y * e1.x - duv1.y * e2.x,
				duv2.y * e1.y - duv1.y * e2.y,
				duv2.y * e1.z - duv1.y * e2.z
			});
			binormal := normalize(f * Vector3.{
				-duv2.x * e1.x + duv1.x * e2.x,
				-duv2.x * e1.y + duv1.x * e2.y,
				-duv2.x * e1.z + duv1.x * e2.z
			});

			tangents[i1] += tangent;
			tangents[i2] += tangent;
			tangents[i3] += tangent;

			binormals[i1] += binormal;
			binormals[i2] += binormal;
			binormals[i3] += binormal;
		}
		for * tangents normalize(it);
		for * binormals normalize(it);
	}

	// print("ok\n");
	return .{
		points = vertices3,
		indices = indices,
		normals = normals3,
		tangents = tangents,
		binormals = binormals,
		uvs = uvs2,
		most_general = .UVN,
		gl_ready = true
	}, texture_albedo, texture_normal;
}

SRC_VERT_MINIMUM :: #string GLSL
	#version 430 core
	layout (location = 0) in vec3 a_pos;
	layout (location = 1) in vec2 a_uv;
	layout (location = 2) in vec3 a_normal;
	layout (location = 3) in vec3 a_tangent;
	layout (location = 4) in vec3 a_binormal;

	uniform mat4 u_vp;
	uniform mat4 u_m;

	out struct Vert_Out {
		vec3 pos;
		vec2 uv;

		vec3 normal;
		vec3 tangent;
		vec3 binormal;
	} vert_out;

	void main() {
		vec4 p = u_m * vec4(a_pos, 1);
		vert_out.pos = p.xyz;

		vert_out.normal = a_normal; // TODO
		vert_out.tangent = a_tangent;
		vert_out.binormal = a_binormal;

		vert_out.uv = a_uv;
		gl_Position = u_vp * p;
	}
GLSL
SRC_FRAG_SHOW_MAPS :: #string GLSL
	#version 430 core
	layout(binding = 0) uniform sampler2D u_color;
	layout(binding = 1) uniform sampler2D u_normal;

	in struct Vert_Out {
		vec3 pos;
		vec2 uv;

		vec3 normal;
		vec3 tangent;
		vec3 binormal;
	} vert_out;

	out vec4 o_color;
	uniform float u_time;

	vec3 get_normal(vec2 uv) {
		vec3 n1 = normalize(vert_out.normal);
		vec3 n2 = normalize(vert_out.tangent);
		vec3 n3 = normalize(vert_out.binormal);

		vec3 nm = texture(u_normal, uv).xyz * 2 - 1;
		return n1 * nm.z + n2 * nm.x + n3 * nm.y;
	}

	struct Light_Source {
		vec3 pos;
		float strength;
	};

	vec3 get_lulimnance(Light_Source light, vec3 normal) {
		vec3 light_dir = light.pos - vert_out.pos;
		float light_dist = length(light_dir);
		float angle_factor = max(dot(light_dir / light_dist, normal), 0);
		float dist_factor = 1 / (.1 + light_dist * light_dist);
		float strength = 10;
		return vec3(angle_factor * dist_factor * light.strength);
	}

	void main() {
		vec2 uv = vert_out.uv;
		vec3 normal = get_normal(uv);

		vec3 l0 = get_lulimnance(Light_Source(
			vec3(sin(u_time), 0, cos(u_time)) * 3 + vec3(0, 0, 0),
			10
		), normal);

		vec3 base_color = texture(u_color, uv).xyz;
		vec3 result_color = base_color * (l0 + .1);

		o_color = vec4(result_color, 1);
	}
GLSL