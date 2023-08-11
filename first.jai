IMPORT_EXTRA_PATH :: "/home/cyanmargh/projects/jai/";

MAIN_DEMO :u8: 10; // set MAIN_DEMO = DEMO_COUNT to build all demos
EXE_PREFIX :: "demo_"; 
EXECS_DIR :: "execs";

GEN_PACKS :: true;

Demo_Data :: struct {
	name : string;
	resources : []string;
}

#import "Basic";
#import "Compiler";
#import "Process";
#import "File";

demos_data :: Demo_Data.[
	.{"loading models and calculating normals", .["6th_platonic_solid.obj"]},	
	.{"framebuffer test", .["6th_platonic_solid.obj"]},	
	.{"pendulum fractal", .[]},	
	.{"order independent transparency", .["cow.obj"]},
	.{"advanced particles", .[]},
	.{"voxels (wip)", .[]},
	.{"integer in vbo (test)", .[]},
	.{"watercolor", .[]},
	.{"magic eye renderer", .["6th_platonic_solid.obj"]},
	.{"filters", .["input_texture.png"]},
	// .{"chunk map", .[]},
	// .{"skin mask", .["skin.png", "uv64.png"]}
];
DEMO_COUNT :: demos_data.count;

EXE_SUFFIX :: #run ifx OS == .WINDOWS then ".exe" else ".elf";
#run {
	set_build_options_dc(.{do_output=false});

	make_directory_if_it_does_not_exist("builds");
	make_directory_if_it_does_not_exist("execs");

	if MAIN_DEMO == DEMO_COUNT {
		for i : 0..DEMO_COUNT-1 {
			build_demo(i);
		}
	} else if MAIN_DEMO < DEMO_COUNT {
		build_demo(MAIN_DEMO);
	}
	make_link();
}


build_demo :: (demo_id : int) {
	main_id := ifx demo_id < DEMO_COUNT then demo_id else DEMO_COUNT - 1;
	name := demos_data[demo_id].name;
	added_defs := false;

	w := compiler_create_workspace(name);
	if !w {
		print("Workspace creation failed.\n");
		return;
	}

	target_options := get_build_options(w);
	{
		using target_options;
		text_output_flags = 0;
		// optimization_level = .RELEASE;

		output_executable_name = sprint("%1%2", EXE_PREFIX, demo_id);
		import_path = .[import_path[0], IMPORT_EXTRA_PATH];

		// output_path = EXECS_DIR;
	}

	set_build_options(target_options, w);

	compiler_begin_intercept(w);
	add_build_file(tprint("%/main.jai", #filepath), w);
	add_build_file(tprint("%/demos/demo_%.jai", #filepath, demo_id), w);
	#if OS == .WINDOWS add_build_string("#run (#import \"Windows_Resources\").disable_runtime_console();", w);
	add_build_string(sprint("DEMO_ID :: %;", demo_id), w);

	while 1 {
		message := compiler_wait_for_message();
		if message.kind == {
			case .COMPLETE;
	//TODO fix it
			#if OS == .LINUX run_command("mv", tprint("./%1%2", EXE_PREFIX, demo_id), tprint("./%1%2%3", EXE_PREFIX, demo_id, EXE_SUFFIX));
			#if GEN_PACKS pack(demo_id);
			run_command("mv", tprint("./%1%2%3", EXE_PREFIX, demo_id, EXE_SUFFIX), tprint("./%4/%1%2%3", EXE_PREFIX, demo_id, EXE_SUFFIX, EXECS_DIR));

			if demo_id == main_id make_link();
			break;
		}
	}
	compiler_end_intercept(w);
}

make_link :: () {
	id_active := ifx MAIN_DEMO == DEMO_COUNT then DEMO_COUNT - 1 else MAIN_DEMO;
	run_command("ln", "-s", "-f", tprint("./%4/%1%2%3", EXE_PREFIX, id_active, EXE_SUFFIX, EXECS_DIR), tprint("main%", EXE_SUFFIX));
}

pack :: (demo_id : int) {
	args : [..]string; defer array_free(args);

	array_add(*args, "tar");
	array_add(*args, "czf");
	array_add(*args, tprint("./builds/result_%.tar.gz", demo_id));
	array_add(*args, tprint("%1%2%3", EXE_PREFIX, demo_id, EXE_SUFFIX));
	for s : demos_data[demo_id].resources {
		array_add(*args, tprint("res/%", s));
	}
	run_command(..args);
}
