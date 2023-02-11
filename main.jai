#import "Basic";
#import "String";
#import "Window_Creation";
Input :: #import "Input";
#import "Math";
#import "File";
#import "File_Utilities";
#import "System";
#import "GL";
#import "Hash_Table";
simp :: #import "Simp";
getrect :: #import "GetRect";
#load "shaders.jai";

vec3 :: Vector3;
vec2 :: Vector2;

Point :: struct {
	pos : vec3;
	uv : vec2;
}
Mesh_Raw :: struct {
	points : []Point;
}
Mesh_UV :: struct {
	vao, vbo, points_count : u32;
	// ebo : u32;
}
// offsetof :: ($T : Type, $field : string) -> s64 {
// 	info := type_info(T);
// 	if info.type != .STRUCT return -1;
// 	for type_info(T).members {
// 		if equal(it.name, "ccc") return it.offset_in_bytes;
// 	}
// 	return -1;
// }
add_attribs :: ($T : Type) {
	for m, i : type_info(T).members {
		print("-> % % % %\n", i, (m.type.runtime_size / size_of(float)), size_of(T), m.offset_in_bytes);
		glVertexAttribPointer(xx i, xx (m.type.runtime_size / size_of(float)), GL_FLOAT, GL_FALSE, size_of(T), cast(*void) m.offset_in_bytes);
		check_gl_error("3");
		glEnableVertexAttribArray(xx i);
		check_gl_error("4");
	}
}
// message_callback :: (source : u32,
//                  type : u32,
//                  id : u32,
//                  severity : u32,
//                  length : u32,
//                  message : *u8,
//                  userParam : *void) #c_call {
// 	printf("GL CALLBACK: type = %x, severity = %x, message = %s\n", type, severity, message);
// }

make_mesh_uv :: (mesh_raw : Mesh_Raw) -> Mesh_UV {
	// glEnable(GL_DEBUG_OUTPUT);
	// glDebugMessageCallback(message_callback, null);

	using mesh : Mesh_UV;
	points_count = xx mesh_raw.points.count;
	glGenVertexArrays(1, *vao);
	glGenBuffers(1, *vbo);
	glBindVertexArray(vao);

	check_gl_error("0");

	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, mesh_raw.points.count * size_of(Point), mesh_raw.points.data, GL_STATIC_DRAW);

	check_gl_error("1");

	add_attribs(Point);

	check_gl_error("2");

	glBindVertexArray(0);
	return mesh;
}
clear_mesh_uv :: (using mesh_uv : Mesh_UV) {
	glDeleteVertexArrays(1, *vao);
	glDeleteBuffers(1, *vbo);
}
draw :: (using mesh_uv : Mesh_UV) {
	glBindVertexArray(vao);
	glDrawArrays(GL_TRIANGLES, 0, points_count);
}

Shader_Part :: struct {
	id : u32;
}
Shader :: struct {
	id : u32;
}

AF :: (obj : *$T) -> *T #expand {
	`defer free(obj);
	return obj;
}

from_c_string :: (c_str : *[$N]s8) -> string {
	str : string;
	str.data = cast(*u8) c_str;
	str.count = N;
	return str;
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
	return .{id = id};
}
clear_shader :: (s : Shader) {
	glDeleteProgram(s.id);
}
use :: (s : Shader) {
	glUseProgram(s.id);
}


should_exit := false;
color_id := 0;
colors := Vector3.[.{.3, .1, .1}, .{.1, .3, .1}, .{.1, .1, .3}];
rect_src := Mesh_Raw.{
	points = Point.[
		Point.{vec3.{-1, -1, 0}, vec2.{0, 0}},
		Point.{vec3.{ 1, -1, 0}, vec2.{1, 0}},
		Point.{vec3.{ 1,  1, 0}, vec2.{1, 1}},
		Point.{vec3.{-1, -1, 0}, vec2.{0, 0}},
		Point.{vec3.{ 1,  1, 0}, vec2.{1, 1}},
		Point.{vec3.{-1,  1, 0}, vec2.{0, 1}}
	]
};

handle_event :: (event : Input.Event) {
	getrect.getrect_handle_event(event);
	if event.type == {
	case .QUIT;
		should_exit = true;
	case .KEYBOARD;
		if event.key_pressed {
			if event.key_code == .ESCAPE {
				should_exit = true;
			} else if event.key_code == .F4 && event.alt_pressed {
				should_exit = true;
			} else if event.key_code == .SPACEBAR {
				color_id = (color_id + 1) % colors.count;
			}
		}
	}
}

check_gl_error :: (str := "-") {
	err := glGetError();
	if err print("error(%) = %\n", str, err);
}

main :: () {
	check_gl_error("-2");

	window := create_window(1200, 800, "name here");
	simp.set_render_target(window);

	check_gl_error("-1");

	mesh := make_mesh_uv(rect_src); defer clear_mesh_uv(mesh);

	shader := make_shader_vf(SRC_VERT, SRC_FRAG); defer clear_shader(shader);

	while !should_exit {
		Input.update_window_events();

		for Input.events_this_frame handle_event(it);

		col := colors[color_id];
		simp.clear_render_target(col.x, col.y, col.z, 1);

		use(shader);
		draw(mesh);

		simp.swap_buffers(window);
	}

	// glEnable(GL_BLEND);
}

