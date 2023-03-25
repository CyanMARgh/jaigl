vec4 :: Vector4;
vec3 :: Vector3;
vec2 :: Vector2;

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



check_gl_error :: (str := "-") {
	err := glGetError();
	if err print("error(%) = %\n", str, err);
}

fract :: (x : float) -> float { return x - floor(x); }
fract :: (using v : vec2) -> vec2 { return .{fract(x), fract(y)}; }
fract :: (using v : vec3) -> vec3 { return .{fract(x), fract(y), fract(z)}; }
fract :: (using v : vec4) -> vec4 { return .{fract(x), fract(y), fract(z), fract(w)}; }

floor :: (v : vec2) -> vec2 { return .{floor(v.x), floor(v.y)}; }
floor :: (v : vec3) -> vec3 { return .{floor(v.x), floor(v.y), floor(v.z)}; }
floor :: (v : vec4) -> vec4 { return .{floor(v.x), floor(v.y), floor(v.z), floor(v.w)}; }

mix :: (x : float, y : float, m : float) -> float { return x + (y - x) * m; } 
mix :: (x : vec2, y : vec2, m : float) -> vec2 { return .{mix(x.x, y.x, m), mix(x.y, y.y, m)}; } 
mix :: (x : vec3, y : vec3, m : float) -> vec3 { return .{mix(x.x, y.x, m), mix(x.y, y.y, m), mix(x.z, y.z, m)}; } 
mix :: (x : vec4, y : vec4, m : float) -> vec4 { return .{mix(x.x, y.x, m), mix(x.y, y.y, m), mix(x.z, y.z, m), mix(x.w, y.w, m)}; } 

mix :: (x : vec2, y : vec2, m : vec2) -> vec2 { return .{mix(x.x, y.x, m.x), mix(x.y, y.y, m.y)}; } 
mix :: (x : vec3, y : vec3, m : vec3) -> vec3 { return .{mix(x.x, y.x, m.x), mix(x.y, y.y, m.y), mix(x.z, y.z, m.z)}; } 
mix :: (x : vec4, y : vec4, m : vec4) -> vec4 { return .{mix(x.x, y.x, m.x), mix(x.y, y.y, m.y), mix(x.z, y.z, m.z), mix(x.w, y.w, m.z)}; } 

clamp :: (a : vec2, mi : float, ma : float) -> vec2 { return .{clamp(a.x, mi, ma), clamp(a.y, mi, ma)}; }
clamp :: (a : vec3, mi : float, ma : float) -> vec3 { return .{clamp(a.x, mi, ma), clamp(a.y, mi, ma), clamp(a.z, mi, ma)}; }
clamp :: (a : vec4, mi : float, ma : float) -> vec4 { return .{clamp(a.x, mi, ma), clamp(a.y, mi, ma), clamp(a.z, mi, ma), clamp(a.w, mi, ma)}; }


sin :: (v : vec2) -> vec2 { return .{sin(v.x), sin(v.y)}; }
sin :: (v : vec3) -> vec3 { return .{sin(v.x), sin(v.y), sin(v.z)}; }
sin :: (v : vec4) -> vec4 { return .{sin(v.x), sin(v.y), sin(v.z), sin(v.w)}; }

hash22 :: (_p : vec2, seed := vec2.{}) -> vec2 {
	p := multiply(Matrix2.{127.1, 311.7, 269.5, 183.3}, cast(Vector2) _p);

	p = vec2.{-1., -1.} + 2. * fract(sin(p) * 43758.545);
	return sin(p * 6.283 + seed * vec2.{124.1, 8123.1});
}

perlin_level :: (p : vec2) -> float {
	pi := floor(p);
	pf := p - pi;
	w := pf * pf * (vec2.{3., 3.} - vec2.{2., 2.} * pf);

	f00 := dot(hash22(pi + vec2.{0., 0.}), pf - vec2.{0., 0.});
	f01 := dot(hash22(pi + vec2.{0., 1.}), pf - vec2.{0., 1.});
	f10 := dot(hash22(pi + vec2.{1., 0.}), pf - vec2.{1., 0.});
	f11 := dot(hash22(pi + vec2.{1., 1.}), pf - vec2.{1., 1.});

	return mix(mix(f00, f10, w.x), mix(f01, f11, w.x), w.y);   
}
perlin :: (_p : Vector2) -> float {
	p := _p;
	M1 :: 4;

	a, r, s := 1., 0., 0.;
	for i : 0..M1 - 1 {
		r += a * perlin_level(p);
		s += a;
		p *= 2.;
		a *= .5;
	}
	return r / s;
}

hsv2rgb :: (c : vec3) -> vec3 {
	K := vec4.{1, 2. / 3, 1. / 3, 3};
	p := abs(fract(vec3.{c.x, c.x, c.x} + K.xyz) * 6.0 - vec3.{K.w, K.w, K.w});
	return c.z * mix(vec3.{K.x, K.x, K.x}, clamp(p - vec3.{K.x, K.x, K.x}, 0, 1), c.y);
}