Frame_Buffer :: struct {
	width, height : u32;
	tex_depth, tex_color : Texture;
	// id_color, id_depth : u32;
	fbo, rbo : u32; 
}

make_frame_buffer :: (_width : u32, _height : u32) -> Frame_Buffer, bool {
	using frame_buffer := Frame_Buffer.{width = _width, height = _height};

	glGenFramebuffers(1, *fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);

		tex_color = make_texture(_width, _height, GL_RGB, GL_RGB, GL_UNSIGNED_BYTE, .[GL_TEXTURE_MIN_FILTER, GL_NEAREST, GL_TEXTURE_MAG_FILTER, GL_NEAREST]);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, tex_color.id, 0);

		tex_depth = make_texture(_width, _height, GL_DEPTH_COMPONENT, GL_DEPTH_COMPONENT, GL_FLOAT, .[GL_TEXTURE_MIN_FILTER, GL_NEAREST, GL_TEXTURE_MAG_FILTER, GL_NEAREST]);
		glFramebufferTexture2D(GL_DEPTH_COMPONENT, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, tex_depth.id, 0);

		glGenRenderbuffers(1, *rbo);
		glBindRenderbuffer(GL_RENDERBUFFER, rbo);
			glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, width, height);
		glBindRenderbuffer(GL_RENDERBUFFER, 0);

		if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE {
			print("ERROR: Framebuffer is not complete!\n");
		}
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, tex_depth.id, 0);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	return frame_buffer, true;
}
clear_frame_buffer :: (using frame_buffer : Frame_Buffer) {
	clear_texture(tex_depth);
	clear_texture(tex_color);
	glDeleteRenderbuffers(1, *rbo);
	glDeleteFramebuffers(1, *fbo);
}
bind :: (buf : Frame_Buffer) {
	glViewport(0, 0, buf.width, buf.height);
	glBindFramebuffer(GL_FRAMEBUFFER, buf.fbo);
}