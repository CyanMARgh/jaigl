#import "Process";
#import "Basic";
#import "File";
#import "stb_image_resize";

#if OS == .WINDOWS {
	#import "Windows";
} else {
	#import "POSIX";
}

FFMPEG :: struct {
	process : Process;
	buffer : Frame;

	fps : int;
	frames : int;
	time : float;
	dt : float;
	length_frames := -1;
	ended := false;
}
ffmpeg_start_rendering :: (width : int, height : int, fps := 60, filename := "output.mp4", path := ".", bitrate := 2500, length_seconds := -1.) -> FFMPEG, ok:bool {
	ffmpeg := FFMPEG.{
		buffer = make_frame(width, height),
		fps = fps,
		dt = 1. / fps,
		length_frames = ifx length_seconds < 0 then -1 else xx (length_seconds * fps) 
	};

	make_directory_if_it_does_not_exist(path, true);
	success := create_process(*ffmpeg.process,
		"ffmpeg",
		"-loglevel", "verbose",
		"-y",
		"-f", "rawvideo",
		"-pix_fmt", "rgba",
		"-s", tprint("%x%", width, height),
		"-r", tprint("%", fps),
		"-i", "-",
		"-c:v", "libx264",
		"-vb", tprint("%k", bitrate),
		"-c:a", "aac",
		"-ab", "200k",
		"-pix_fmt", "yuv420p",
		tprint("%/%", path, filename),
		capture_and_return_output = true
	);
	return ffmpeg, success;
}
ffmpeg_end_rendering :: (ffmpeg : *FFMPEG) {
	#if OS == .WINDOWS {
		fclose(ffmpeg.process.input.handle); //not sure about this
	} else {
		close(ffmpeg.process.input.handle);
	}
	success, result := get_process_result(*ffmpeg.process);
	clear(ffmpeg.buffer);
}
ffmpeg_send_frame :: (ffmpeg : *FFMPEG) {
	ffmpeg_send_frame_helper(ffmpeg, ffmpeg.buffer);
}
ffmpeg_add_screenshot :: (using ffmpeg : *FFMPEG) {
	fill_frame_with_screenshot(*buffer);
	ffmpeg_send_frame(ffmpeg);
}
ffmpeg_scale_and_send_frame :: (ffmpeg : *FFMPEG, input_frame : Frame) -> ok:bool {
	resized := input_frame;
	if ffmpeg.buffer.width != input_frame.width && ffmpeg.buffer.height != input_frame.height {		
		stbir_resize_uint8(
			xx input_frame.pixels, xx input_frame.width, xx input_frame.height, xx(input_frame.width * 4),
			xx ffmpeg.buffer.pixels, xx ffmpeg.buffer.width, xx ffmpeg.buffer.height, xx(ffmpeg.buffer.width * 4),
			4
		);
		resized = ffmpeg.buffer;
	}
	ffmpeg_send_frame_helper(ffmpeg, resized);
	return true;
}

ffmpeg_send_frame_helper :: (using ffmpeg : *FFMPEG, frame : Frame) {
	bytes := frame.bytes;
	while bytes.count > 0 {
		succes, bytes_written := write_to_process(*process, bytes);
		bytes.data += bytes_written;
		bytes.count -= bytes_written;
	}
	frames += 1;
	time = frames * dt;
	ended = frames >= length_frames;
}

Frame :: struct {
	width, height : int;
	bytecount : int;
	pixels : *u32;
	#place bytecount;
	bytes : []u8;
}
make_frame :: (width : int, height : int) -> Frame {
	return .{
		width = width,
		height = height,	
		bytes = NewArray(width * height * 4, u8)
	};
}
clear :: (using frame : Frame) {
	array_free(bytes);
}

fill_frame_with_screenshot :: (using frame : *Frame) {
	glReadPixels(0, 0, xx width, xx height, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
	for y1 : 0..(height / 2 - 1) {
		y2 := height - y1 - 1;
		row1 := pixels + y1 * width;
		row2 := pixels + y2 * width;
		for x : 0..width-1 {
			row1[x], row2[x] = row2[x], row1[x];
		}
	}
}