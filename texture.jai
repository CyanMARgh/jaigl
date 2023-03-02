Texture :: struct {
	id : u32;
	width, height, dim : u32;
	format : GLenum;
}

make_texture :: (width : u32, height : u32, format : GLenum, channels : GLenum, type : GLenum, params : []GLenum, src : *u8 = null, mipmap := true, storage := false) -> Texture {
	result := Texture.{width = width, height = height, format = format};

	glGenTextures(1, *result.id);
	glBindTexture(GL_TEXTURE_2D, result.id);
		for i : 0..params.count/2 - 1 {
			glTexParameteri(GL_TEXTURE_2D, xx params[i * 2], xx params[i * 2 + 1]);
		}
		if storage {
			glTextureStorage2D(result.id, 1, xx format, width, height);
		} else {
			glTexImage2D(GL_TEXTURE_2D, 0, xx format, xx width, xx height, 0, channels, type, src);
			if mipmap glGenerateMipmap(GL_TEXTURE_2D);
		}
	glBindTexture(GL_TEXTURE_2D, 0);

	return result;
}

load_texture :: (path : string) -> Texture {
	using result : Texture;

	cstr_path := to_c_string("test.png"); defer free(cstr_path);
	data := stbi_load(cstr_path, xx *width, xx *height, xx *dim, 4); defer stbi_image_free(data);

	print("loading texture (%): % x % x %\n", path, width, height, dim);
	if(!data) {
		print("failed to load\n");
		exit(1);
	}
	fmt : GLenum;
	if dim == 1 {
		fmt = GL_RED;
		print("fmt = GL_RED\n");
	} else if dim == 3 || dim == 4 {
		fmt = GL_RGBA; // TODO ????
		print("fmt = GL_RGBA\n");
	} else {
		print("unknown format\n");
		exit(1);
	}

	glGenTextures(1, *id);				//create
	glBindTexture(GL_TEXTURE_2D, id);	//

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, xx ifx fmt == GL_RGBA then GL_CLAMP_TO_EDGE else GL_REPEAT);	//create (params array)
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, xx ifx fmt == GL_RGBA then GL_CLAMP_TO_EDGE else GL_REPEAT);	//
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);												//
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);												//
 
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);	//create (src = data/null)
	glGenerateMipmap(GL_TEXTURE_2D);																		//create (optional)

	glBindTexture(GL_TEXTURE_2D, 0);	//create

	return result;
}
clear_texture :: (using texture : Texture) {
	glDeleteTextures(1, *id);
}
bind_texture :: (texture_id : u32, bind_id : u32) {
	glActiveTexture(GL_TEXTURE0 + bind_id);
	glBindTexture(GL_TEXTURE_2D, texture_id);
}
bind :: (texture : Texture, bind_id : u32) {
	bind_texture(texture.id, bind_id);
}
bind_as_storage :: (texture : Texture, bind_id : u32) {
	glBindImageTexture(bind_id, texture.id, 0, GL_FALSE, 0, GL_WRITE_ONLY, texture.format);
	// TODO 								?     ?      ?      ?
}

make_image :: (width : u32, height : u32, format : GLenum) -> Texture {
	return make_texture(width, height, format, 0, 0, .[
			GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE,
			GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE, 
			GL_TEXTURE_MIN_FILTER, GL_NEAREST,
			GL_TEXTURE_MAG_FILTER, GL_NEAREST
		 ], storage = true);
}
