// Generic_Vector :: struct(Type)


ivec2 :: struct {
	x, y : s32;
}
operator+ :: (a : ivec2, b : ivec2) -> ivec2 {
	return .{a.x + b.x, a.y + b.y};
}
operator- :: (a : ivec2, b : ivec2) -> ivec2 {
	return .{a.x - b.x, a.y - b.y};
}
operator- :: (a : ivec2) -> ivec2 {
	return .{-a.x, -a.y};
}
operator* :: (a : ivec2, b : s32) -> ivec2 {
	return .{a.x * b, a.y * b};
}
operator/ :: (a : ivec2, b : s32) -> ivec2 {
	return .{a.x / b, a.y / b};
}
operator== :: (a : ivec2, b : ivec2) -> bool {
	return a.x == b.x && a.y == b.y;
}

Gen_Vec3 :: struct(T : Type) {
	x, y, z : T;
}
operator+ :: (a : Gen_Vec3($T), b : Gen_Vec3(T)) -> Gen_Vec3(T) {
	return .{a.x + b.x, a.y + b.y, a.z + b.z};
}
operator* :: (a : Gen_Vec3($T), b : T) -> Gen_Vec3(T) {
	return .{a.x * b, a.y * b, a.z * b};
}
operator- :: (a : Gen_Vec3($T), b : Gen_Vec3(T)) -> Gen_Vec3(T) {
	return .{a.x - b.x, a.y - b.y, a.z - b.z};
}
operator/ :: (a : Gen_Vec3($T), b : T) -> Gen_Vec3(T) {
	return .{a.x / b, a.y / b, a.z / b};
}
operator== :: (a : Gen_Vec3($T), b : Gen_Vec3(T)) -> bool {
	return a.x == b.x && a.y == b.y && a.z == b.z;
}
cast_vec :: ($T2 : Type, v : Gen_Vec3($T1)) -> Gen_Vec3(T2) {
	return .{cast(T2)v.x, cast(T2)v.y, cast(T2)v.z};
}
ivec3 :: Gen_Vec3(s32);
u8vec3 :: Gen_Vec3(u8);

Ibox2 :: struct {
	width, height, left, top : s32;
	#place width;
	size : ivec2;
	#place left;
	corner : ivec2;
}
operator== :: (a : Ibox2, b : Ibox2) -> bool {
	return a.size == b.size && a.corner == b.corner;
}
is_empty :: (box : Ibox2) -> bool {
	return box.size == .{0, 0};
}
is_invalid :: (box : Ibox2) -> bool {
	return box.width < 0 || box.height < 0;
}
point_inside :: (point : ivec2, zone : Ibox2) -> bool {
	return point.x >= zone.left && point.y >= zone.top && point.x < zone.left + zone.width && point.y < zone.top + zone.height;
}
inside :: (inner : Ibox2, outer : Ibox2) -> bool {
	icorner2 := inner.corner + inner.size;
	ocorner2 := outer.corner + outer.size;
	return
		inner.corner.x >= outer.corner.x && inner.corner.y >= outer.corner.y &&
		icorner2.x <= ocorner2.x && icorner2.y <= ocorner2.y;
}
inside :: (inner : Ibox2, outer : ivec2) -> bool {
	icorner2 := inner.corner + inner.size;
	return
		inner.corner.x >= 0 && inner.corner.y >= 0 &&
		icorner2.x <= outer.x && icorner2.y <= outer.y;
}
inside :: (inner : ivec2, outer : ivec2) -> bool {
	return inner.x <= outer.x && inner.y <= outer.y;
}
cut_border :: (box : Ibox2, gap : int) -> Ibox2 {
	return .{width = xx(box.width - 2 * gap), height = xx(box.height - 2 * gap), left = xx(box.left + gap), top = xx(box.top + gap)};
}
centered_box :: (zone : Ibox2, box_size : ivec2) -> Ibox2, fit:bool {
	return .{size = box_size, corner = zone.corner + ivec2.{(zone.width - box_size.x) / 2, (zone.height - box_size.y) / 2}}, inside(box_size, zone.size);
}

intersection :: (box1 : Ibox2, box2 : Ibox2) -> Ibox2 {
	result : Ibox2 = ---;
	
	result.top = max(box1.top, box2.top);
	result.left = max(box1.left, box2.left);

	result.height = min(box1.top + box1.height, box2.top + box2.height) - result.top;
	result.width = min(box1.left + box1.width, box2.left + box2.width) - result.left;

	return result;
}