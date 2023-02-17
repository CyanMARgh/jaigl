vec4 :: Vector4;
vec3 :: Vector3;
vec2 :: Vector2;

// auto free
AF :: (obj : *$T) -> *T #expand {
	`defer free(obj);
	return obj;
}

from_c_string :: (c_str : *[$N]s8) -> string {
	str : string;
	str.data = cast(*u8) c_str;
	str.count = N;
	return str;
}

arr_cast :: (arr : []$Old_Type, $new_type := float32) -> []new_type {
	scale :: #run {
		s1, s2 := size_of(Old_Type), size_of(new_type);
		#assert s1 % s2 == 0;
		return s1 / s2;
	};
	return .{data = cast(*new_type) arr.data, count = arr.count / scale}; 
}
