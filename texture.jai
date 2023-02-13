#import "stb_image";

Texture :: struct {
	id : u32;
	width, height, dim : s32;
}

load_texture :: (path : string) -> Texture {
	using result : Texture;

	cstr_path := to_c_string("test.png"); defer free(cstr_path);
	data := stbi_load(cstr_path, *width, *height, *dim, 4); defer stbi_image_free(data);

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

	glGenTextures(1, *id);
	glBindTexture(GL_TEXTURE_2D, id);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, xx ifx fmt == GL_RGBA then GL_CLAMP_TO_EDGE else GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, xx ifx fmt == GL_RGBA then GL_CLAMP_TO_EDGE else GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
 
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
	glGenerateMipmap(GL_TEXTURE_2D);

	return result;
}
clear_texture :: (using texture : Texture) {
	glDeleteTextures(1, *id);
}
bind :: (texture : Texture, id : u32) {
	glActiveTexture(GL_TEXTURE0 + id);
	glBindTexture(GL_TEXTURE_2D, texture.id);
}