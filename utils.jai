vec4 :: Vector4;
vec3 :: Vector3;
vec2 :: Vector2;

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
