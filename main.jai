#import "Basic"()(MEMORY_DEBUGGER=true);

#load "module.jai";
simp :: #import "Simp";

main :: () {
	defer report_memory_leaks();
	#insert -> string { return tprint("demo_%();", DEMO_ID); }
}
