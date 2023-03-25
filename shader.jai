#import "Hash_Table";

Shader_Part :: struct {
	id : u32;
}
Shader_Options :: struct {
	type : GLuint = 0;
	flags : []string;
	gsx, gsy, gsz : u32;
}
Shader :: struct {
	id : u32;
	fields : Table(string, s32);
	using options : Shader_Options;
}
// TODO add flags support
make_shader_part :: (src : string, type : GLuint, options : Shader_Options = .{}) -> Shader_Part, bool {
	id := glCreateShader(type);
	lines := split(src, cast(u8) #char "\n");
	builder : String_Builder;
	print_to_builder(*builder, "%\n", lines[0]);
	for options.flags {
		print_to_builder(*builder, "#define %\n", it);
	}
	if type == GL_COMPUTE_SHADER {
		if options.gsx || options.gsy || options.gsz {
			assert(options.gsx && options.gsy && options.gsz);
			print_to_builder(*builder, "/*+*/layout(local_size_x = %, local_size_y = %, local_size_z = %) in;\n", options.gsx, options.gsy, options.gsz);
		}
	}
	for id : 1..lines.count-1 {
		print_to_builder(*builder, "%\n", lines[id]);
	}
	append(*builder, "\0");
	c_src := builder_to_string(*builder); defer free(c_src);

	glShaderSource(id, 1, *(c_src.data), null);
	glCompileShader(id);
	succes : s32;
	info_log : [512]s8;
	glGetShaderiv(id, GL_COMPILE_STATUS, *succes);
	if !succes {
		glGetShaderInfoLog(id, 512, null, cast(*GLchar) *info_log);
		print("failed to compile shader: %\n", from_c_string(*info_log));		
		print("source = \n");
		for line, id : split(c_src, cast(u8) #char "\n") {
			print("[%] %\n", id + 1, line);
		}
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
make_shader_c :: (src_comp : string, gsx : u32 = 8, gsy : u32 = 4, gsz : u32 = 1, flags : []string = .[]) -> Shader {
	options := Shader_Options.{GL_COMPUTE_SHADER, flags, gsx, gsy, gsz};
	comp := make_shader_part(src_comp, GL_COMPUTE_SHADER, options); defer clear_shader_part(comp);

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
	shader := Shader.{id = id, options = options};
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
compute :: (using s : Shader, dimx : u32 = 1, dimy : u32 = 1, dimz : u32 = 1, barrier := GL_ALL_BARRIER_BITS, sizelim : u32 = 100000) {
	if dimx > 0 && dimy > 0 && dimz > 0 && dimx < sizelim && dimy < sizelim && dimz < sizelim {
		sx, sy, sz := (dimx - 1) / gsx + 1, (dimy - 1) / gsy + 1, (dimz - 1) / gsz + 1;
		// print("sx, sy, sz = %, %, %\n", sx, sy, sz);
		// print("block dims: % % %\n", gsx, gsy, gsz);
		glDispatchCompute(sx, sy, sz);
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

// with :: (s : *Shader, code : Code, dimx : u32, dimy : u32 = 1, dimz : u32 = 1, barrier := GL_ALL_BARRIER_BITS, sizelim : u32 = 100000) #expand {
// 	assert(s.type == GL_COMPUTE_SHADER);
// 	set :: (field : string, value : $T) #expand {
// 		set(`s, field, value);
// 	}
// 	use(<<s);
// 	#insert,scope() code;
// 	compute(<<s, dimx, dimy, dimz, barrier, sizelim);
// }