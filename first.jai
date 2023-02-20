#import "Basic";
#import "Compiler";
#import "Process";

#run {
	w := compiler_create_workspace("Target Program");
	if !w {
	    print("Workspace creation failed.\n");
	    return;
	}

	target_options := get_build_options(w);
	{
		using target_options;

		optimization_level = .RELEASE;
		write_added_strings = false;
		stack_trace = false; 
		array_bounds_check = .OFF;

		cast_bounds_check = .OFF;
		math_bounds_check = .OFF;
		target_options.null_pointer_check = .OFF;
		backtrace_on_crash = .OFF;
		emit_debug_info = .NONE;

		emit_debug_info = .NONE;
		llvm_options.code_gen_optimization_level = 3;
		llvm_options.enable_split_modules = false;

		enable_bytecode_inliner = true;
		enable_frame_pointers   = false;

		output_executable_name = "main";
	}

	set_build_options(target_options, w);

	compiler_begin_intercept(w);
	add_build_file(tprint("%/main.jai", #filepath), w); // up 2

	while 1 {
		message := compiler_wait_for_message();
		if message.kind == {
			case .COMPLETE;
			run_command("tar", "czf", "result.tar.gz", "main"/*, "test.png", "6th_platonic_solid.obj"*/);
			break;
		}
	}
	compiler_end_intercept(w);	

	set_build_options_dc(.{do_output=false});
}