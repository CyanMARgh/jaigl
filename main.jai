#import "Basic";
#import "String";
#import "Window_Creation";
Input :: #import "Input";
#import "Math";
#import "Input";
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
#load "load_obj.jai";
#load "camera.jai";


should_exit := false;
color_id := 0;
cube_src := Mesh_Raw.{
	points = .[
		-.5, -.5, -.5,  0, 0,
		-.5,  .5, -.5,  1, 0,
		 .5,  .5, -.5,  1, 1,
		 .5, -.5, -.5,  0, 1,

		-.5, -.5,  .5,  0, 0,
		 .5, -.5,  .5,  1, 0,
		 .5,  .5,  .5,  1, 1,
		-.5,  .5,  .5,  0, 1,

		-.5, -.5,  .5,  0, 0,
		-.5,  .5,  .5,  1, 0,
		-.5,  .5, -.5,  1, 1,
		-.5, -.5, -.5,  0, 1,

		 .5,  .5, -.5,  0, 0,
		 .5,  .5,  .5,  1, 0,
		 .5, -.5,  .5,  1, 1,
		 .5, -.5, -.5,  0, 1,

		 .5, -.5, -.5,  0, 0,
		 .5, -.5,  .5,  1, 0,
		-.5, -.5,  .5,  1, 1,
		-.5, -.5, -.5,  0, 1,

		-.5,  .5,  .5,  0, 0,
		 .5,  .5,  .5,  1, 0,
		 .5,  .5, -.5,  1, 1,
		-.5,  .5, -.5,  0, 1
	],
	indices = .[
		 0,  1,  2,  0,  2,  3,
		 4,  5,  6,  4,  6,  7,
		 8,  9, 10,  8, 10, 11,
		12, 13, 14, 12, 14, 15,
		16, 17, 18, 16, 18, 19,
		20, 21, 22, 20, 22, 23
	 ]
};
rect_src := Mesh_Raw.{
	points = .[
		-1, -1, 0,     0, 0,
		 1, -1, 0,     1, 0,
		 1,  1, 0,     1, 1,
		-1,  1, 0,     0, 1
	],
	indices = .[0, 1, 2, 0, 2, 3]
};

pressed_keys : [1024]bool;


update_keys_list :: (event : Input.Event) {
}
handle_event :: (event : Input.Event) {
	getrect.getrect_handle_event(event);
	if event.type == {
	case .QUIT;
		should_exit = true;
	case .KEYBOARD;
		if event.key_pressed {
			if event.key_code == .ESCAPE || event.key_code == .F4 && event.alt_pressed {
				should_exit = true;
			}
		}
		pressed_keys[event.key_code] = !!event.key_pressed; 
	}
}

check_gl_error :: (str := "-") {
	err := glGetError();
	if err print("error(%) = %\n", str, err);
}

main :: () {
	window := create_window(1200, 800, "name here");
	simp.set_render_target(window);
	camera : Camera;

	mesh := make_mesh(cube_src, Point_UV); defer clear_mesh(mesh);
	shader := make_shader_vf(SRC_VERT, SRC_JUST_TEXTURE_FRAG); defer clear_shader(*shader);
	texture := load_texture("test.png"); defer clear_texture(texture);

	time := current_time_monotonic();
	while !should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;

		Input.update_window_events();
		move_camera(*camera, xx dt);

		for Input.events_this_frame handle_event(it);

		simp.clear_render_target(.1, .3, .3, 1);

		glClear(GL_DEPTH_BUFFER_BIT);
		glEnable(GL_DEPTH_TEST);

		use(shader);
			bind(texture, 0);
			set(*shader, "u_transform", get_transform(*camera, .{1200, 800}));
			// set(*shader, "u_blue", .5);
		draw(mesh);

		simp.swap_buffers(window);
	}
}

