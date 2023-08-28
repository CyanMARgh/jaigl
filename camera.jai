Camera :: struct {
	yaw, pitch : float;
	position := Vector3.{0, 0, 8};

	pitch_limit := PI * .5;
}
move_camera :: (using cam : *Camera, dt : float, pressed_keys : [1024]bool, speed_factor := 1.) {
	linear_speed, angular_speed := 4. * speed_factor, 2.;
	d_yaw, d_pitch := 0.;
	direction : Vector3;

	if pressed_keys[#char "W"] 		   direction.z -= 1;
	if pressed_keys[#char "S"] 		   direction.z += 1;
	if pressed_keys[#char "A"] 		   direction.x -= 1;
	if pressed_keys[#char "D"] 		   direction.x += 1;
	if pressed_keys[Input.Key_Code.SPACEBAR] direction.y += 1;	
	if pressed_keys[Input.Key_Code.SHIFT]    direction.y -= 1;	

	if pressed_keys[#char "Q"] d_yaw   += 1;
	if pressed_keys[#char "E"] d_yaw   -= 1;
	if pressed_keys[#char "R"] d_pitch += 1;
	if pressed_keys[#char "F"] d_pitch -= 1;

	yaw += d_yaw * angular_speed * dt;
	pitch += d_pitch * angular_speed * dt;
	Clamp(*pitch, -pitch_limit, pitch_limit);

	direction = rotate(direction, Quaternion.{0, sin(yaw / 2), 0, cos(yaw / 2)});
	position += direction * linear_speed * dt;
}
print_mat :: (mat : Matrix4) {
	for f, i : mat.floats {
		print("%\t\t", f);
		if i % 4 == 3 print("\n");
	}
	print("\n");
}
get_transform :: (using cam : Camera, ws : Vector2) -> Matrix4 {
	v, p := get_transform_v_p(cam, ws);
	return p * v;
}

get_transform_v_p :: (using cam : Camera, ws : Vector2) -> Matrix4, Matrix4 {
	move := make_translation_matrix4(-position);
	rotate := rotation_matrix(Matrix4, 
		Quaternion.{sin(-pitch / 2), 0, 0, cos(-pitch / 2)} * 
		Quaternion.{0, sin(-yaw / 2), 0, cos(-yaw / 2)}
	);
	proj := make_projection_matrix(PI * .3, ws.x / ws.y, 0.1, 100);

	return rotate * move, proj;
}
