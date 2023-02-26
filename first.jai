#import "Basic";
#import "Compiler";
#import "Process";
#import "File";

MAIN_DEMO :u8: 5; // set MAIN_DEMO = DEMO_COUNT to build all demos
EXE_PREFIX :: "demo_"; 


DEMO_COUNT :u8: 5;
resources_list :: []string.[
	.["cow.obj"],
	.["6th_platonic_solid.obj"],
	.[],
	.["cow.obj"],
	.[]
];
names :: string.[
	"loading models and calculating normals",	
	"framebuffer test",	
	"pendulum fractal",	
	"order independent transparency",
	"advanced particles"
];


EXE_SUFFIX :: #run ifx OS == .WINDOWS then ".exe" else ".elf";
#run {
	set_build_options_dc(.{do_output=false});

	make_directory_if_it_does_not_exist("builds");

	if MAIN_DEMO == DEMO_COUNT {
		for i : 0..DEMO_COUNT-1 {
			build_demo(i);
		}
	} else if MAIN_DEMO < DEMO_COUNT {
		build_demo(MAIN_DEMO);
	}
	make_link();
}

make_link :: () {
	id_active := ifx MAIN_DEMO == DEMO_COUNT then DEMO_COUNT - 1 else MAIN_DEMO;
	run_command("ln", "-s", "-f", tprint("%1%2%3", EXE_PREFIX, id_active, EXE_SUFFIX), tprint("main%", EXE_SUFFIX));
}
gen_tar_args :: (files : []string, exe_name : string, archive_name : string) -> []string {
	result : [..]string;
	array_add(*result, "tar");
	array_add(*result, "czf");
	array_add(*result, archive_name);
	array_add(*result, exe_name);
	for s : files {
		array_add(*result, tprint("res/%", s));
	}
	return result;
}

build_demo :: (demo_id : u32) {
	name := names[demo_id];
	added_defs := false;

	w := compiler_create_workspace("Target Program");
	if !w {
		print("Workspace creation failed.\n");
		return;
	}

	target_options := get_build_options(w);
	{
		using target_options;
		optimization_level = .RELEASE;

		output_executable_name = sprint("%1%2", EXE_PREFIX, demo_id);
	}

	set_build_options(target_options, w);

	compiler_begin_intercept(w);
	add_build_file(tprint("%/main.jai", #filepath), w);
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
			#if OS == .LINUX run_command("mv", tprint("%1%2", EXE_PREFIX, demo_id), tprint("%1%2%3", EXE_PREFIX, demo_id, EXE_SUFFIX));
			args := gen_tar_args(resources_list[demo_id], tprint("%1%2%3", EXE_PREFIX, demo_id, EXE_SUFFIX), tprint("builds/result_%.tar.gz", demo_id));
			run_command(..args);
			break;
		}
	}
	compiler_end_intercept(w);
}