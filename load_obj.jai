#import "Random";
#import "File";

randf01 :: #bake_arguments random_get_within_range(min = 0, max = 1);

random_bright_color :: () -> vec3 {
	r := vec3.{randf01(), randf01(), randf01()};
	r /= max(r.x, r.y, r.z);
	return r;
}

load_obj :: (obj_path: string) -> Mesh_Raw, bool {
	obj_data, success := read_entire_file(obj_path);	
	if !success {
		print("couldn't load file: %\n", obj_path);
		return .{}, false;
	} 
	defer free(obj_data);

	points : [..]float;
	indices : [..]u32;

	lines := split(obj_data, "\n");
	for lines {
		line_elems := split(it, " ");
		if line_elems[0] == "v" {
			x := string_to_float(line_elems[1]);
			y := string_to_float(line_elems[2]);
			z := string_to_float(line_elems[3]);
			array_add(*points, x);
			array_add(*points, y);
			array_add(*points, z);
		}	
		
		else if line_elems[0] == "f" {
			v0 := split(line_elems[1], "/");
			v1 := split(line_elems[2], "/");
			v2 := split(line_elems[3], "/");

			idp0 := string_to_int(v0[0]);
			idp1 := string_to_int(v1[1]);
			idp2 := string_to_int(v2[2]);

			array_add(*indices, cast(u32) idp0);
			array_add(*indices, cast(u32) idp1);
			array_add(*indices, cast(u32) idp2);
		}
	}

	return .{points, indices}, true;
}