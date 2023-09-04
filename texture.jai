Texture :: struct {
	id : u32;
	width, height, dim : u32;
	format : GLenum;
}

make_texture :: (width : u32, height : u32, format : GLenum, params : []GLenum, src : *u8 = null, src_channels :u32= GL_RGBA, src_data_type :u32= GL_UNSIGNED_BYTE, mipmap := false, storage := false) -> Texture {
	result := Texture.{width = width, height = height, format = format};

	glGenTextures(1, *result.id);
	glBindTexture(GL_TEXTURE_2D, result.id);
		for i : 0..params.count/2 - 1 {
			glTexParameteri(GL_TEXTURE_2D, xx params[i * 2], xx params[i * 2 + 1]);
		}
		if storage {
			glTextureStorage2D(result.id, 1, xx format, width, height);
		} else {
			glTexImage2D(GL_TEXTURE_2D, 0, xx format, xx width, xx height, 0, src_channels, src_data_type, src);
		}
		if mipmap glGenerateMipmap(GL_TEXTURE_2D);
	glBindTexture(GL_TEXTURE_2D, 0);

	return result;
}
//TODO                              remove
load_texture :: (path : string, storage_type := GL_RGBA32F, interpolation :u32= GL_LINEAR) -> Texture {
	cstr_path := to_c_string(path); defer free(cstr_path);
	width, height, dim : s32;
	data := stbi_load(cstr_path, *width, *height, *dim, 4); defer stbi_image_free(data);

	print("loading texture (%): % x % x %\n", path, width, height, dim);
	if(!data) {
		print("failed to load\n");
		exit(1);
	}
	src_channels : GLenum;
	if dim == 1 {
		src_channels = GL_RED;
		print("fmt = GL_RED\n");
	} else if dim == 3 || dim == 4 {
		src_channels = GL_RGBA; // TODO ????
		print("fmt = GL_RGBA\n");
	} else {
		print("unknown format\n");
		exit(1);
	}

	return make_texture(xx width, xx height, GL_RGBA32F, .[
		GL_TEXTURE_WRAP_S, xx GL_REPEAT,
		GL_TEXTURE_WRAP_T, xx GL_REPEAT,
		GL_TEXTURE_MIN_FILTER, interpolation,
		GL_TEXTURE_MAG_FILTER, interpolation
	], data, src_channels, GL_UNSIGNED_BYTE, true);
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
bind_as_storage :: (texture : Texture, bind_id : u32, access_mode :u32= GL_READ_WRITE) {
	glBindImageTexture(bind_id, texture.id, 0, GL_FALSE, 0, access_mode, texture.format);
	// TODO 								?     ?      ?
}

make_storage :: (width : u32, height : u32, format : GLenum) -> Texture {
	return make_texture(width, height, format, .[
		GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE,
		GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE,
		GL_TEXTURE_MIN_FILTER, GL_NEAREST,
		GL_TEXTURE_MAG_FILTER, GL_NEAREST
	 ], storage = true);
}
