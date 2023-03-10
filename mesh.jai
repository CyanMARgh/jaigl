clear_mesh_raw :: (using mesh : Mesh_Raw) {
	array_free(points);
	array_free(indices);
}
Mesh :: struct {
	vao, vbo, ebo : u32;
	points_count, indices_count : u32;
	has_ebo : bool;
}
get_primary_type :: (t : *Type_Info) -> *Type_Info {
	tt := t.type;
	if tt == .STRUCT {
		return get_primary_type((cast(*Type_Info_Struct)t).members[0].type);
	}
	return t;
}
add_attribs :: ($T : Type) {
	stride : u32 = 0;
	for m : type_info(T).members {
		stride += xx m.type.runtime_size;
	}
	for m, i : type_info(T).members {
		pt := get_primary_type(m.type);
		data_type : GLenum;
		if pt.type == .FLOAT {
			data_type = GL_FLOAT;
		} else if pt.type == .INTEGER {
			signed := (cast(*Type_Info_Integer)pt).signed;
			if pt.runtime_size == 4 && signed {
				data_type = GL_INT;
			} else {
				print("invalid type : %\n", pt);
				exit(1);
			}
		} else {
			print("invalid type : %\n", pt);
			exit(1);
		}
		print("glVertexAttribPointer: %, %, %, %, %, %\n",
			i,
			xx (m.type.runtime_size / pt.runtime_size),
			ifx data_type == GL_INT then "INTEGER" else ifx data_type == GL_FLOAT then "FLOAT" else "???",
			GL_FALSE,
			stride,
			m.offset_in_bytes
		);
		glVertexAttribPointer(xx i, xx (m.type.runtime_size / pt.runtime_size), data_type, GL_FALSE, stride, cast(*void) m.offset_in_bytes);
		glEnableVertexAttribArray(xx i);
	}
}
make_mesh_soa :: (mesh_raw_soa : Mesh_Raw_SOA, draw_mode := GL_STATIC_DRAW) -> Mesh {
	using mesh : Mesh;

	has_ebo = xx mesh_raw_soa.indices;
	points_count = cast(u32) mesh_raw_soa.points.count;
	indices_count = cast(u32) mesh_raw_soa.indices.count;

	glGenVertexArrays(1, *vao);
	glGenBuffers(1, *vbo);
	glBindVertexArray(vao);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);

	if has_ebo {
		glGenBuffers(1, *ebo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, mesh_raw_soa.indices.count * size_of(u32), mesh_raw_soa.indices.data, xx draw_mode);
	}

	s_points := mesh_raw_soa.points.count * size_of(vec3);
	s_uvs    := mesh_raw_soa.uvs.count * size_of(vec2);
	s_normals:= mesh_raw_soa.normals.count * size_of(vec3);
	vbo_size := s_points + s_uvs + s_normals;
	glBufferData(GL_ARRAY_BUFFER, vbo_size, null, xx draw_mode);

	glBufferSubData(GL_ARRAY_BUFFER, 0, s_points, mesh_raw_soa.points.data);
	//                    i
	glVertexAttribPointer(0, xx (size_of(vec3) / size_of(float)), GL_FLOAT, GL_FALSE, 0, cast(*void) 0);
	glEnableVertexAttribArray(0);

	glBufferSubData(GL_ARRAY_BUFFER, s_points, s_uvs, mesh_raw_soa.uvs.data);
	//                    i
	glVertexAttribPointer(1, xx (size_of(vec2) / size_of(float)), GL_FLOAT, GL_FALSE, 0, cast(*void) s_points);
	glEnableVertexAttribArray(1);

	glBufferSubData(GL_ARRAY_BUFFER, s_points + s_uvs, s_normals, mesh_raw_soa.normals.data);
	//                    i
	glVertexAttribPointer(2, xx (size_of(vec3) / size_of(float)), GL_FLOAT, GL_FALSE, 0, cast(*void) s_points + s_uvs);
	glEnableVertexAttribArray(2);

	glBindVertexArray(0);
	return mesh;
}
make_mesh :: (mesh_raw : Mesh_Raw, $ptype : Type, draw_mode := GL_STATIC_DRAW) -> Mesh {
	using mesh : Mesh;

	has_ebo = xx mesh_raw.indices;
	points_count = cast(u32) mesh_raw.points.count / (size_of(ptype) / size_of(float));
	indices_count = cast(u32) mesh_raw.indices.count;

	glGenVertexArrays(1, *vao);
	glGenBuffers(1, *vbo);
	glBindVertexArray(vao);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);

	if has_ebo {
		glGenBuffers(1, *ebo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, indices_count * size_of(u32), mesh_raw.indices.data, xx draw_mode);
	}

	glBufferData(GL_ARRAY_BUFFER, points_count * size_of(ptype), mesh_raw.points.data, xx draw_mode);
	add_attribs(ptype);
	glBindVertexArray(0);
	return mesh;
}
make_empty_mesh_no_ebo :: (count : u32, $ptype : Type, draw_mode := GL_DYNAMIC_DRAW) -> Mesh {
	using mesh : Mesh;

	has_ebo = false;
	points_count, indices_count = count, 0;

	glGenVertexArrays(1, *vao);
	glGenBuffers(1, *vbo);
	glBindVertexArray(vao);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);

	glBufferData(GL_ARRAY_BUFFER, points_count * size_of(ptype), null, xx draw_mode);
	add_attribs(ptype);
	glBindVertexArray(0);
	return mesh;
}
clear_mesh :: (using mesh_uv : Mesh) {
	glDeleteVertexArrays(1, *vao);
	glDeleteBuffers(1, *vbo);
	if has_ebo {
		glDeleteBuffers(1, *ebo);
	}
}
draw :: (using mesh_uv : Mesh, mode := GL_TRIANGLES, actual_size :u32= 0xFFFFFFFF) {
	glBindVertexArray(vao);
	if has_ebo {
		glDrawElements(xx mode, ifx actual_size == 0xFFFFFFFF then indices_count else actual_size, GL_UNSIGNED_INT, null);
	} else {
		glDrawArrays(xx mode, 0, ifx actual_size == 0xFFFFFFFF then points_count else actual_size);
	}
}
bind_vbo_as_storage :: (mesh : Mesh, offset : u32 = 0) {
	glBindVertexArray(mesh.vao);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, offset, mesh.vbo);
}
