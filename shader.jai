#import "Hash_Table";

Shader_Part :: struct {
	id : u32;
}
Shader :: struct {
	id : u32;
	fields : Table(string, s32);
}
make_shader_part :: (src : string, type : GLuint/*, flags : []string = string.[]*/) -> Shader_Part, bool {
	id := glCreateShader(type);
	c_src := AF(to_c_string(src));
	glShaderSource(id, 1, *c_src, null);
	glCompileShader(id);
	succes : s32;
	info_log : [512]s8;
	glGetShaderiv(id, GL_COMPILE_STATUS, *succes);
	if !succes {
		glGetShaderInfoLog(id, 512, null, cast(*GLchar) *info_log);
		print("failed to compile shader: %\n", from_c_string(*info_log));
		glDeleteShader(id);
		return .{}, false;
	}
	print("shader compiling done\n");
	return .{id = id}, true;
}
clear_shader_part :: (sp : Shader_Part) {
	glDeleteShader(sp.id);
}
make_shader_vf :: (src_vert : string, src_frag : string) -> Shader {
	vert := make_shader_part(src_vert, GL_VERTEX_SHADER); defer clear_shader_part(vert);
	frag := make_shader_part(src_frag, GL_FRAGMENT_SHADER); defer clear_shader_part(frag);

	id := glCreateProgram();
	glAttachShader(id, vert.id);
	glAttachShader(id, frag.id);
	glLinkProgram(id);
	print("linking done\n");

	shader := Shader.{id = id};
	init(*shader.fields);

	return shader;
}
make_shader_vgf :: (src_vert : string, src_geom : string, src_frag : string) -> Shader {
	vert := make_shader_part(src_vert, GL_VERTEX_SHADER); defer clear_shader_part(vert);
	geom := make_shader_part(src_geom, GL_GEOMETRY_SHADER); defer clear_shader_part(geom);
	frag := make_shader_part(src_frag, GL_FRAGMENT_SHADER); defer clear_shader_part(frag);

	id := glCreateProgram();
	glAttachShader(id, vert.id);
	glAttachShader(id, geom.id);
	glAttachShader(id, frag.id);
	glLinkProgram(id);
	print("linking done\n");

	shader := Shader.{id = id};
	init(*shader.fields);

	return shader;
}
make_shader_c :: (src_comp : string) -> Shader {
	comp := make_shader_part(src_comp, GL_COMPUTE_SHADER); defer clear_shader_part(comp);

	id := glCreateProgram();
	glAttachShader(id, comp.id);
	glLinkProgram(id);
	succes : s32;
	info_log : [512]s8;
	glGetProgramiv(id, GL_LINK_STATUS, *succes);
	if !succes {
		glGetProgramInfoLog(id, 512, null, cast(*GLchar) *info_log);
		print("failed to link shader: %\n", from_c_string(*info_log));
		glDeleteProgram(id);
		return .{};
	}

	print("shader linking done\n");
	shader := Shader.{id = id};
	init(*shader.fields);

	return shader;
}
clear_shader :: (using s : *Shader) {
	glDeleteProgram(id);
	deinit(*fields);
}
use :: (using s : Shader) {
	glUseProgram(id);
}
compute :: (using s : Shader, dimx : u32, dimy : u32, scalex : u32 = 8, scaley : u32 = 4, barrier := GL_ALL_BARRIER_BITS) {
	if dimx > 0 && dimy > 0 && dimx < 10000 && dimy < 10000 {
		sx, sy := (dimx-1) / scalex + 1, (dimy-1) / scaley + 1;
		// print("sx, sy = %, %\n", sx, sy);
		glDispatchCompute(sx, sy, 1);
		glMemoryBarrier(GL_ALL_BARRIER_BITS);		
	}
}

find_id :: (s : *Shader, field : string) -> s32 {
	idptr, new := find_or_add(*s.fields, field);
	if new {
		cstr_field := to_c_string(field);
		<<idptr = glGetUniformLocation(s.id, cstr_field);
		free(cstr_field);
	}
	return <<idptr;
}
set :: (s : *Shader, field : string, value : float) {
	glUniform1f(find_id(s, field), value);
}
set :: (s : *Shader, field : string, value : vec3) {
	glUniform3f(find_id(s, field), value.x, value.y, value.z);
}
set :: (s : *Shader, field : string, value : Matrix4) {
	glUniformMatrix4fv(find_id(s, field), 1, GL_TRUE, xx *value);
}
set :: (s : *Shader, field : string, value : u32) {
	glUniform1ui(find_id(s, field), value);
}