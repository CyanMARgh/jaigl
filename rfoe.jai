#import "Basic";
#import "Math";

main :: () {
	ws := Vector2.{1.5, 1};
	screen_matrix := make_frustum_matrix(-ws.x / ws.y, ws.x / ws.y, -1, 1, 0.1, 100, true);

	for f, i : screen_matrix.floats {
		print("%\t\t", f);
		if i % 4 == 3 print("\n");
	}
	// x := 10;
	// y := *x;
	// print("%\n", y[0]);
	// file_data, ok := read_entire_file("scene.fbx");
	// if !ok exit(-1);
	// scene := ofbx.load(file_data.data, file_data.count, .{}, .{});

}
