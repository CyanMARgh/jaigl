#import "Basic"()(MEMORY_DEBUGGER=true);

#placeholder DEMO_ID;
#load "cmglib.jai";
simp :: #import "Simp";

main :: () {
	defer report_memory_leaks();
	#insert #run tprint("demo_%();", DEMO_ID);
}
