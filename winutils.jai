camera_rail :: (using camera : *Camera, t : float) {
	yaw, pitch = t * .1, 0;
	position = rotate(vec3.{0, 1.5, 5}, Quaternion.{0, sin(yaw / 2), 0, cos(yaw / 2)});
}

close_window :: (window: Window_Type) {
	#if OS == .WINDOWS {
		Windows :: #import "Windows";
		Windows.DestroyWindow(window);
	} else #if OS == .LINUX {
		X11 :: #import "X11";
		X11.XDestroyWindow(X11.x_global_display, window);
	}
}

Win_State :: struct {
	should_exit := false;
	pressed_keys : [1024]bool;	
}

handle_event :: (using state : *Win_State, event : Input.Event) {
	getrect.getrect_handle_event(event);
	if event.type == {
	case .QUIT;
		should_exit = true;
	case .KEYBOARD;
		if event.key_pressed {
			if event.key_code == .ESCAPE || event.key_code == .F4 && event.alt_pressed {
				should_exit = true;
			}
		}
		pressed_keys[event.key_code] = !!event.key_pressed; 
	}
}