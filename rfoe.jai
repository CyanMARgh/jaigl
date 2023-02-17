#import "Basic"()(MEMORY_DEBUGGER=true);
#import "Math";
#import "String";
#import "System";

main :: () {
	defer report_memory_leaks();

	arr := NewArray(10000, int);
	defer array_free(arr);
	arr = .[];

	// data : []int;
	// array_free(data);
	// print("% %\n", data.count, data.data);
}
