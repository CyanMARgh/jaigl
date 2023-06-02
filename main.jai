#import "Basic"()(MEMORY_DEBUGGER=true);

#load "cmglib.jai";
simp :: #import "Simp";

main :: () {
	defer report_memory_leaks();
	#insert -> string { return tprint("demo_%();", DEMO_ID); }
}
