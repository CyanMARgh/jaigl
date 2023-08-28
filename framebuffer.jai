Frame_Buffer :: struct {
	width, height : u32;
	tex_depth, tex_color, tex_alpha : Texture;
	// id_color, id_depth : u32;
	fbo, rbo : u32; 
	use_alpha := false;
}

make_frame_buffer :: (_width : u32, _height : u32, add_alpha := false, hdr := false) -> Frame_Buffer, bool {
	using frame_buffer := Frame_Buffer.{width = _width, height = _height, use_alpha = add_alpha};

	glGenFramebuffers(1, *fbo);
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);
		//format=GL_RGB16F src_channels=GL_RGB src_data_type=GL_FLOAT
		// make_texture :: (width : u32, height : u32, format : GLenum, params : []GLenum, src : *u8 = null, src_channels :u32= GL_RGBA, src_data_type :u32= GL_UNSIGNED_BYTE, mipmap := false, storage := false) -> Texture {
		if hdr {
			tex_color = make_texture(_width, _height, GL_RGB16F, .[
					GL_TEXTURE_MIN_FILTER, GL_NEAREST,
					GL_TEXTURE_MAG_FILTER, GL_NEAREST
				],
				null, GL_RGB, GL_FLOAT,
			);
			if add_alpha {
				tex_alpha = make_texture(_width, _height, GL_R16F, .[
						GL_TEXTURE_MIN_FILTER, GL_NEAREST,
						GL_TEXTURE_MAG_FILTER, GL_NEAREST
					],
					null, GL_RED, GL_FLOAT,
				);			
			}
		} else {
			tex_color = make_texture(_width, _height, GL_RGB, .[
					GL_TEXTURE_MIN_FILTER, GL_NEAREST,
					GL_TEXTURE_MAG_FILTER, GL_NEAREST
				],
				null, GL_RGB, GL_UNSIGNED_BYTE,
			);
			if add_alpha {
				tex_alpha = make_texture(_width, _height, GL_RED, .[
						GL_TEXTURE_MIN_FILTER, GL_NEAREST,
						GL_TEXTURE_MAG_FILTER, GL_NEAREST
					],
					null, GL_RED, GL_UNSIGNED_BYTE,
				);
			}
		}
		tex_depth = make_texture(_width, _height, GL_DEPTH_COMPONENT, .[
				GL_TEXTURE_MIN_FILTER, GL_NEAREST,
				GL_TEXTURE_MAG_FILTER, GL_NEAREST
			],
			null, GL_DEPTH_COMPONENT, GL_FLOAT
		);
		check_gl_error();

		glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, tex_color.id, 0);
		glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, tex_alpha.id, 0);
		glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, tex_depth.id, 0);

		if glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE {
			print("ERROR: Framebuffer is not complete!\n");
		}
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	return frame_buffer, true;
}
clear_frame_buffer :: (using frame_buffer : Frame_Buffer) {
	clear_texture(tex_depth);
	clear_texture(tex_color);
	clear_texture(tex_alpha);
	// glDeleteRenderbuffers(1, *rbo);
	glDeleteFramebuffers(1, *fbo);
}
bind :: (using buf : Frame_Buffer) {
	glViewport(0, 0, width, height);
	glBindFramebuffer(GL_FRAMEBUFFER, fbo);
	if use_alpha {
		buffers := u32.[GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1];
		glDrawBuffers(2, buffers.data);
	}
}