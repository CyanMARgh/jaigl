Atomic_Counter :: struct {
	id : u32;
	make :: () -> Atomic_Counter {
		using result : Atomic_Counter;
		glGenBuffers(1, *id);
		glBindBuffer(GL_ATOMIC_COUNTER_BUFFER, id);
			glBufferData(GL_ATOMIC_COUNTER_BUFFER, size_of(u32), null, GL_DYNAMIC_DRAW);
		glBindBuffer(GL_ATOMIC_COUNTER_BUFFER, 0);
		return result;
	}
}
bind :: (using counter : Atomic_Counter, offset : u32 = 0) {
	glBindBufferBase(GL_ATOMIC_COUNTER_BUFFER, offset, id);
}
get :: (using counter : Atomic_Counter) -> u32 {
	glBindBuffer(GL_ATOMIC_COUNTER_BUFFER, id);
	ptr := glMapBuffer(GL_ATOMIC_COUNTER_BUFFER, GL_READ_ONLY);
	val := << cast(*u32) ptr;
	glUnmapBuffer(GL_ATOMIC_COUNTER_BUFFER);
	return val;

}
clear :: (using counter : Atomic_Counter) {
	glDeleteBuffers(1, *id);
}
reset :: (using counter : Atomic_Counter, val : u32 = 0) {
	glBindBuffer(GL_ATOMIC_COUNTER_BUFFER, id);
	glBufferSubData(GL_ATOMIC_COUNTER_BUFFER, 0, size_of(u32), *val);
	glBindBuffer(GL_ATOMIC_COUNTER_BUFFER, 0);
}

Shader_Storage :: struct {
	id : u32;
	size : u32;
	make :: (count : u32, el_size : u32 = 1) -> Shader_Storage {
		using result : Shader_Storage;
		size = count * el_size;
		glGenBuffers(1, *id);
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, id);
			glBufferData(GL_SHADER_STORAGE_BUFFER, size, null, GL_DYNAMIC_DRAW);
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
		return result;
	}
}
clear :: (using storage : Shader_Storage) {
	glDeleteBuffers(1, *id);
}
bind :: (using storage : Shader_Storage, offset : u32 = 0) {
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, offset, id);
}
