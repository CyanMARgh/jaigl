// auto free
AF :: (obj : *$T) -> *T #expand {
	`defer free(obj);
	return obj;
}
AC :: (obj : *$T) -> *T #expand {
	`defer clear(obj);
	return obj;
}

from_c_string :: (c_str : *[$N]s8) -> string {
	str : string;
	str.data = cast(*u8) c_str;
	str.count = N;
	return str;
}

__sarr :: (size : $int, data : ..$T) -> [size]T {
	result : [size]T;
	array_copy(*result, data);
	return result;
}

__arr_cast :: (arr : []$Old_Type, $new_type := float32) -> []new_type {
	scale :: #run {
		s1, s2 := size_of(Old_Type), size_of(new_type);
		#assert s1 % s2 == 0;
		return s1 / s2;
	};
	return .{data = cast(*new_type) arr.data, count = arr.count / scale}; 
}
__dyn :: (elems : ..$T, allocator := Allocator.{}) -> [..]T {
	result : [..]T;
	array_copy(*result, elems);
	return result;
}


check_gl_error :: (loc := #caller_location) {
	has_errors := false;
	while true {
		err := glGetError();
		if !err break;
		has_errors = true;
		print("error at line %, file %. code = %\n", loc.line_number, loc.fully_pathed_filename, err);
	}
}

