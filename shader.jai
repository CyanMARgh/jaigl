#import "Hash_Table";

Shader_Part :: struct {
	id : u32;
}
Shader :: struct {
	id : u32;
	fields : Table(string, s32);
}
make_shader_part :: (src : string, type : GLuint/*, flags : []string = string.[]*/) -> Shader_Part {
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
	}
	print("shader compiling done\n");
	return .{id = id};
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
clear_shader :: (using s : *Shader) {
	glDeleteProgram(id);
	deinit(*fields);
}
use :: (using s : Shader) {
	glUseProgram(id);
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