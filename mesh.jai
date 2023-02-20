clear_mesh_raw :: (using mesh : Mesh_Raw) {
	array_free(points);
	array_free(indices);
}
Mesh :: struct {
	vao, vbo, ebo : u32;
	points_count, indices_count : u32;
	has_ebo : bool;
}
add_attribs :: ($T : Type) {
	for m, i : type_info(T).members {
		glVertexAttribPointer(xx i, xx (m.type.runtime_size / size_of(float)), GL_FLOAT, GL_FALSE, size_of(T), cast(*void) m.offset_in_bytes);
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
	points_count = cast(u32) mesh_raw.points.count;
	indices_count = cast(u32) mesh_raw.indices.count;

	glGenVertexArrays(1, *vao);
	glGenBuffers(1, *vbo);
	glBindVertexArray(vao);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);

	if has_ebo {
		glGenBuffers(1, *ebo);
		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
		glBufferData(GL_ELEMENT_ARRAY_BUFFER, mesh_raw.indices.count * size_of(u32), mesh_raw.indices.data, xx draw_mode);
	}

	glBufferData(GL_ARRAY_BUFFER, mesh_raw.points.count * size_of(ptype), mesh_raw.points.data, xx draw_mode);
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
draw :: (using mesh_uv : Mesh, mode := GL_TRIANGLES) {
	glBindVertexArray(vao);
	if has_ebo {
		glDrawElements(xx mode, indices_count, GL_UNSIGNED_INT, null);
	} else {
		glDrawArrays(xx mode, 0, points_count);
	}
}
