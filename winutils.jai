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
		} else if event.key_code == {
			case #char "P";
			print("\n");
			copy_screen_shot_to_clipboard();
		}
		pressed_keys[event.key_code] = !!event.key_pressed; 
	}
}

copy_screen_shot_to_clipboard :: () {    
	stbi_flip_vertically_on_write(1);
	width, height := simp.get_render_dimensions(__active_window);
	pixels := NewArray(3 * width * height, u8); defer array_free(pixels);
	glReadPixels(0, 0, xx width, xx height, GL_RGB, GL_UNSIGNED_BYTE, xx pixels.data);
	filename := "output.png\0";
	result := stbi_write_png(xx filename.data, width, height, 3, xx pixels.data, width * 3);



	// Convert to FreeImage format & save to file
	// FIBITMAP* image = FreeImage_ConvertFromRawBits(pixels, width, height, 3 * width, 24, 0x0000FF, 0xFF0000, 0x00FF00, false);
	// FreeImage_Save(FIF_BMP, image, "C:/test.bmp", 0);

	// // Free resources
	// FreeImage_Unload(image);
	// delete [] pixels;

}

__active_window : u64;
#scope_file
#import "stb_image_write";