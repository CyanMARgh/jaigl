#import "Basic";
#import "Compiler";
#import "Process";

exe_name :: #run ifx OS == .WINDOWS then "main.exe" else "main";
add_resources :: false;

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

		output_executable_name = "main";
	}

	set_build_options(target_options, w);

	compiler_begin_intercept(w);
	add_build_file(tprint("%/main.jai", #filepath), w);
	#if OS == .WINDOWS add_build_string("#run (#import \"Windows_Resources\").disable_runtime_console();");
	while 1 {
		message := compiler_wait_for_message();
		if message.kind == {
			case .COMPLETE;
			if add_resources {
				run_command("tar", "czf", "result.tar.gz", exe_name, "res");
			} else {
				run_command("tar", "czf", "result.tar.gz", exe_name);				
			}
			break;
		}
	}
	compiler_end_intercept(w);	
	set_build_options_dc(.{do_output=false});
}