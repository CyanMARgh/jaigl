#import "Basic";//()(MEMORY_DEBUGGER=true);

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
#load "load_mtl.jai";
#load "camera.jai";
#load "particles.jai";
#load "framebuffer.jai";
#load "buffers.jai";


should_exit := false;
cube_src :: Mesh_Raw.{
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
rect_src :: Mesh_Raw.{
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

demo_0 :: () {
	mesh_raw_soa, ok := load_obj("res/cow.obj");
	if !ok exit(1);
	prepare(*mesh_raw_soa);
	defer clear_mesh_raw(mesh_raw_soa);

	window := create_window(1200, 800, "model loading"); should_exit = false; defer close_window(window);
	simp.set_render_target(window);
	camera : Camera;

	mesh := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh);
	shader := make_shader_vf(SRC_VERT, SRC_DRAW_NORMALS_FRAG); defer clear_shader(*shader);

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
		glEnable(GL_CULL_FACE);

		use(shader);
			set(*shader, "u_transform", get_transform(*camera, .{1200, 800}));
		draw(mesh);

		simp.swap_buffers(window);
		reset_temporary_storage();
        sleep_milliseconds(10);
	}
}

camera_rail :: (using camera : *Camera, t : float) {
	yaw, pitch = t * .1, 0;
	position = rotate(vec3.{0, 1.5, 5}, Quaternion.{0, sin(yaw / 2), 0, cos(yaw / 2)});
}

demo_1 :: () {
	window := create_window(1200, 800, "framebuffer test"); should_exit = false; defer close_window(window);
	simp.set_render_target(window);
	camera : Camera;

	mesh_raw_soa := load_obj("res/6th_platonic_solid.obj");
	prepare(*mesh_raw_soa); defer clear_mesh_raw(mesh_raw_soa);

	mesh_scene := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh_scene);
	// shader := make_shader_vgf(SRC_PARTICLE_VERT, SRC_PARTICLE_GEOM, SRC_PARTICLE_FRAG); defer clear_shader(*shader);
	mesh_rect := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_rect);

	shader_scene := make_shader_vf(SRC_VERT, SRC_DRAW_NORMALS_FRAG); defer clear_shader(*shader_scene);
	shader_screen := make_shader_vf(SRC_SCREEN_VERT, SRC_SCREEN_FRAG); defer clear_shader(*shader_screen);

	frame_buffer := make_frame_buffer(1200, 800); defer clear_frame_buffer(*frame_buffer);

	time := current_time_monotonic();
	time0 := time;

	while !should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);

		Input.update_window_events();
		for Input.events_this_frame handle_event(it);

		camera_rail(*camera, xx current_time);

		{
			bind(frame_buffer); defer simp.set_render_target(window);

			simp.clear_render_target(.0, .0, .2, 1);
			glClear(GL_DEPTH_BUFFER_BIT);
			
			glDepthMask(GL_TRUE);	
			glEnable(GL_DEPTH_TEST);

			use(shader_scene);
				transform := get_transform(*camera, .{1200, 800});
				set(*shader_scene, "u_transform", transform);
			draw(mesh_scene);			
		}

		simp.clear_render_target(.1, .0, .2, 1);
		glClear(GL_DEPTH_BUFFER_BIT);
		
		use(shader_screen);
			bind(frame_buffer.tex_color, 0);
			bind(frame_buffer.tex_depth, 1);
		draw(mesh_rect);			

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

demo_2 :: () {
	window := create_window(1200, 800, "magnetic pendulum fractal"); should_exit = false; defer close_window(window);
	simp.set_render_target(window);

	mesh_screen := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_screen);

	state_buf := make_image(1200, 800, GL_RGBA32F);

	shader_screen := make_shader_vf(SRC_SCREEN_VERT, SRC_PENDULUM_SCREEN_FRAG); defer clear_shader(*shader_screen);
	shader_init := make_shader_c(SRC_PENDULUM_INIT_COMP); defer clear_shader(*shader_init);
	shader_iterate := make_shader_c(SRC_PENDULUM_ITERATE_COMP); defer clear_shader(*shader_iterate);

	use(shader_init);
		bind_as_storage(state_buf, 0);
	compute(shader_init, 1200, 800);	

	time := current_time_monotonic();
	time0 := time;

	started := true;
	while !should_exit {
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);

		Input.update_window_events();
		for Input.events_this_frame handle_event(it);

		simp.clear_render_target(0, 0, 0, 1);
		glClear(GL_DEPTH_BUFFER_BIT);

		if started {
			use(shader_iterate);
				bind_as_storage(state_buf, 0);
				set(*shader_iterate, "u_time", cast(float) current_time);
				set(*shader_iterate, "u_dtime", cast(float) dt);
			compute(shader_iterate, 1200, 800);

			use(shader_screen);
				bind(state_buf, 0);
			draw(mesh_screen);
		} else if pressed_keys[#char "S"] {
			started = true;
		}


		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

demo_3 :: () {
	width, height : u32 = 1200, 800;
	max_nodes : u32 =  width * height * 5;

	mesh_raw_soa, ok := load_obj("res/cow.obj");
	if !ok exit(1);
	prepare(*mesh_raw_soa);
	defer clear_mesh_raw(mesh_raw_soa);

	window := create_window(width, height, "model loading"); should_exit = false; defer close_window(window);
	simp.set_render_target(window);
	camera : Camera;

	mesh_scene := make_mesh_soa(mesh_raw_soa); defer clear_mesh(mesh_scene);
	mesh_screen := make_mesh(rect_src, Point_UV); defer clear_mesh(mesh_screen);

	Color_Node :: struct {
		color : vec4;
		prev : u32;
		depth : float;
	}
	buf_nodes := Shader_Storage.make(max_nodes, size_of(Color_Node)); defer clear(buf_nodes);
	counter_nodes := Atomic_Counter.make(); defer clear(counter_nodes);
	//											TODO    	----. 
	buf_heads := make_image(width, height, GL_R32UI);

	shader_to_nodes := make_shader_vf(SRC_VERT, SRC_OIT_TO_NODES_FRAG); defer clear_shader(*shader_to_nodes);
	shader_from_nodes := make_shader_vf(SRC_SCREEN_VERT, SRC_OIT_FROM_NODES_FRAG); defer clear_shader(*shader_from_nodes);
	shader_reset := make_shader_c(SRC_OIT_CLEAR_COMP); defer clear_shader(*shader_reset);

	time := current_time_monotonic();
	time0 := time;
	while !should_exit {
		// sim & input
		new_time := current_time_monotonic();
		dt := to_float64_seconds(new_time - time); time = new_time;
		current_time := to_float64_seconds(new_time - time0);
		Input.update_window_events();
		move_camera(*camera, xx dt);
		for Input.events_this_frame handle_event(it);

		// render
		use(shader_reset);
			bind_as_storage(buf_heads, 0);
		compute(shader_reset, width, height);
		reset(counter_nodes);

		// scene
		{
			simp.clear_render_target(.1, .3, .3, 1);
			glClear(GL_DEPTH_BUFFER_BIT);

			use(shader_to_nodes);
				set(*shader_to_nodes, "u_transform", get_transform(*camera, .{xx width, xx height}));
				set(*shader_to_nodes, "u_max_nides", max_nodes);
				set(*shader_to_nodes, "u_time", cast(float)current_time);
				bind_as_storage(buf_heads, 0);
				bind(counter_nodes, 0);
				bind(buf_nodes, 0);
			draw(mesh_scene);
		}

		simp.clear_render_target(.3, .1, .3, 1);
		glClear(GL_DEPTH_BUFFER_BIT);
		use(shader_from_nodes);
			bind_as_storage(buf_heads, 0);
			bind(counter_nodes, 0);
			bind(buf_nodes, 0);
		draw(mesh_screen);

		simp.swap_buffers(window);
		reset_temporary_storage();
		sleep_milliseconds(10);
	}
}

close_window :: (window: Window_Type) {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.DestroyWindow(window);
    } else #if OS == .LINUX {
        X11 :: #import "X11";
        X11.XDestroyWindow(X11.x_global_display, window);
    }
}

#placeholder DEMO_ID;

main :: () {
	#insert #run tprint("demo_%();", DEMO_ID);
}
