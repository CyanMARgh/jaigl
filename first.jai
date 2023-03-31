#import "Basic";
#import "Compiler";
#import "Process";
#import "File";

MAIN_DEMO :u8: 3; // set MAIN_DEMO = DEMO_COUNT to build all demos
EXE_PREFIX :: "demo_"; 
EXECS_DIR :: "execs";

GEN_PACKS :: true;

//TODO to struct
DEMO_COUNT :u8: 8;
resources_list :: []string.[
	.["cow.obj"],
	.["6th_platonic_solid.obj"],
	.[],
	.["cow.obj"],
	.[],
	.[],
	.[],
	.[]
];
names :: string.[
	"loading models and calculating normals",	
	"framebuffer test",	
	"pendulum fractal",	
	"order independent transparency",
	"advanced particles",
	"voxels (wip)",
	"integer in vbo (test)",
	"watercolor"
];


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


build_demo :: (demo_id : u32) {
	main_id := ifx demo_id < DEMO_COUNT then demo_id else DEMO_COUNT - 1;
	name := names[demo_id];
	added_defs := false;

	w := compiler_create_workspace(names[demo_id]);
	if !w {
		print("Workspace creation failed.\n");
		return;
	}

	target_options := get_build_options(w);
	{
		using target_options;
		// optimization_level = .RELEASE;

		output_executable_name = sprint("%1%2", EXE_PREFIX, demo_id);
		// output_path = EXECS_DIR;
	}

	set_build_options(target_options, w);

	compiler_begin_intercept(w);
	add_build_file(tprint("%/main.jai", #filepath), w);
	add_build_file(tprint("%/demos/demo_%.jai", #filepath, demo_id), w);
	#if OS == .WINDOWS add_build_string("#run (#import \"Windows_Resources\").disable_runtime_console();", w);

	while 1 {
		message := compiler_wait_for_message();
		if message.kind == {
			case .PHASE;
			msg_phase := cast(*Message_Phase) message;
			if msg_phase.phase == .TYPECHECKED_ALL_WE_CAN {
				if !added_defs {
					add_build_string(sprint("DEMO_ID :: %;", demo_id), w);
					added_defs = true;
				}
			}

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

pack :: (demo_id : u32) {
	args : [..]string; defer array_free(args);

	array_add(*args, "tar");
	array_add(*args, "czf");
	array_add(*args, tprint("./builds/result_%.tar.gz", demo_id));
	array_add(*args, tprint("%1%2%3", EXE_PREFIX, demo_id, EXE_SUFFIX));
	for s : resources_list[demo_id] {
		array_add(*args, tprint("res/%", s));
	}
	run_command(..args);
}
