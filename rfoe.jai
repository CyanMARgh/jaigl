#import "Basic";
#import "String";

// to_c_string :: (s: string) -> *u8 {
// 	result := cast(*u8) alloc(s.count + 1);
// 	memcpy(result, s.data, s.count);
// 	result[s.count] = 0;

// 	return result;
// }

main :: () {
	// c_str := to_c_string("abcdaf");

	str : [5]s8 = s8.[#char"a", #char"a", #char"a", 0, 0];
	str_2 : string;
	str_2.data = cast(*u8) *str;
	str_2.count = 4;

	print("%", str_2);
}