#import "Basic";
#import "String";
#import "Window_Creation";
Input :: #import "Input";
#import "Math";
// #import "File";
// #import "File_Utilities";
// #import "System";
#import "GL";
// #import "Hash_Table";
simp :: #import "Simp";
getrect :: #import "GetRect";

#load "utils.jai";
#load "shaders_src.jai";
#load "shader.jai";
#load "mesh.jai";
#load "texture.jai";

should_exit := false;
color_id := 0;
colors := Vector3.[.{.3, .1, .1}, .{.1, .3, .1}, .{.1, .1, .3}];
rect_src := Mesh_Raw.{
	points = .[
		.{.{-1, -1, 0}, .{0, 0}},
		.{.{ 1, -1, 0}, .{1, 0}},
		.{.{ 1,  1, 0}, .{1, 1}},
		.{.{-1,  1, 0}, .{0, 1}}
	],
	indices = .[0, 1, 2, 0, 2, 3]
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
	window := create_window(1200, 800, "name here");
	simp.set_render_target(window);

	mesh := make_mesh_uv(rect_src); defer clear_mesh_uv(mesh);
	// shader := make_shader_vf(SRC_VERT, SRC_FRAG); defer clear_shader(*shader);
	shader := make_shader_vf(SRC_VERT, SRC_JUST_TEXTURE_FRAG); defer clear_shader(*shader);
	texture := load_texture("test.png"); defer clear_texture(texture);

	while !should_exit {
		Input.update_window_events();

		for Input.events_this_frame handle_event(it);

		col := colors[color_id];
		simp.clear_render_target(col.x, col.y, col.z, 1);

		use(shader);
			bind(texture, 0);
			// set(*shader, "u_blue", .5);
		draw(mesh);

		simp.swap_buffers(window);
	}
}

