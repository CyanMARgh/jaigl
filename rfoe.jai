#import "Basic";//()(MEMORY_DEBUGGER=true);
#import "String";
#import "Hash_Table";


cm_cmp :: (x : $T, y : T) -> bool {
	S := size_of(T);
	xp := cast(*u8)*x;
	yp := cast(*u8)*y;
	for i : 0..S-1 {
		if xp[i] != yp[i] return false;
	}
	return true;
}

cm_hash :: (x : $T, h : u32 = 5381) -> u32 {
	return inline sdbm_hash(xx *x, size_of(T), h);
}

main :: () {

}
