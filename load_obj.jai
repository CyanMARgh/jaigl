#import "Random";
#import "File";
#import "String";
#import "Hash_Table";
#import "Hash";

Point :: struct {
	pos : vec3;
}
Point_UV :: struct {
	pos : vec3;
	uv : vec2;
}
Point_UV_N :: struct {
	pos : vec3;
	uv : vec2;
	n : vec3;	
}
Mesh_Raw :: struct {
	points : []float;
	indices : []u32;
}

Ftype :: enum_flags u8 {
	P       :: 0b_001;
	UV      :: 0b_011;
	N       :: 0b_101;
	UVN     :: 0b_111;
	INVALID :: 0b_000;
}
Vertice :: struct {
	ids : [3]int;
	type := Ftype.INVALID;
}
Face :: struct {
	MAX_POINTS :: 6;

	ids : [MAX_POINTS * 3]int;
	count : u8;
	type := Ftype.INVALID;
}
Mesh_Raw_SOA :: struct {
	points  : []vec3;
	uvs     : []vec2;
	normals : []vec3;
	union {
		faces : []Face;
		indices : []u32;
	}
	most_general := Ftype.INVALID;
	gl_ready := false;
}
print_mesh_raw_soa :: (using mesh : Mesh_Raw_SOA) {
	if false {
		for p, i : points {
			print("v(%) % % %\n", i, p.x, p.y, p.z);
		}
		print("\n");
		for uv, i : uvs {
			print("vt(%) % %\n", i, uv.x, uv.y);
		}
		print("\n");
		for n, i : normals {
			print("vn(%) % % %\n", i, n.x, n.y, n.z);
		}
		print("\n");
		if !gl_ready {
			for f : faces {
				using f;
				fmt := ifx type == .P " %1" else ifx type == .UV " %1/%2" else ifx type == .N " %1//%3" else " %1/%2/%3"; 
				// fmt := "[%1 %2 %3]";
				print("f");
				for i : 0..count-1 {
					print(fmt, ids[i * 3], ids[i * 3 + 1], ids[i * 3 + 2]);
				}
				print("\n");
			}
		} else {
			for t : 0..(indices.count/3-1) {
				print("f [% % %]\n", mesh.indices[t * 3], mesh.indices[t * 3 + 1], mesh.indices[t * 3 + 2]);
			}
		}
		if indices.count print("\n");
	}
	print("points: %, uvs: %, normals: %, faces/indices: %\ntype: %\ngl_ready: %\n\n",
		points.count, uvs.count, normals.count, faces.count, most_general, gl_ready);
}
clear_mesh_raw :: (using mesh : Mesh_Raw_SOA) {
	array_free(points);
	array_free(uvs);
	array_free(normals);
	if gl_ready {
		array_free(indices);
	} else {
		array_free(faces);
	}
}

load_obj :: (obj_path: string) -> Mesh_Raw_SOA, bool {
	obj_data, success := read_entire_file(obj_path);
	if !success {
		print("couldn't load file: %\n", obj_path);
		return .{}, false;
	} 
	defer free(obj_data);
	obj_view := obj_data;

	points : [..]vec3;
	uvs : [..]vec2;
	normals : [..]vec3;
	faces : [..]Face;
	most_general := Ftype.INVALID;

	end :: ($$ok := false, info := "") #expand {
		if !ok {
			print("failed to load mesh (%), invalid line: %\n", `obj_path, `line_id);
			if info != "" then print("extra info: %\n", info);
			array_free(points);
			array_free(uvs);
			array_free(normals);
			array_free(faces);
			`return .{}, false;
		}
	}
	parse_vec :: (sptr : *string, $T : Type) -> T, bool {
		v : T;
		for * e : v.component {
			ok : bool;
			<<e, ok = parse_float(sptr); if !ok return .{}, false;
		}
		s, ok_suff := parse_token(sptr);
		if ok_suff && s[0] != #char "#" return .{}, false;

		return v, true;
	}

	parse_vertice :: (src : string) -> Vertice {
		c :: (x : Any) -> int {return <<cast(*int)x.value_pointer; }
		using result : Vertice;
		ok, r := scan("%i", src); if ok {
			ids[0] = c(r[0]); type = .P;
			return result;
		} 
		ok, r = scan("%i/%i", src); if ok {
			ids[0], ids[1] = c(r[0]), c(r[1]); type = .UV;
			return result;
		}
		ok, r = scan("%i//%i", src); if ok {
			ids[0], ids[2] = c(r[0]), c(r[1]); type = .N;
			return result;
		}
		ok, r = scan("%i/%i/%i", src); if ok {
			ids[0], ids[1], ids[2] = c(r[0]), c(r[1]), c(r[2]); type = .UVN;
			return result;
		}
		return result;
	}

	parse_face :: (str : *string) -> Face {
		vts : [Face.MAX_POINTS]Vertice;
		count : u8 = 0;
		while count < Face.MAX_POINTS {
			token, ok := parse_token(str);
			if !ok break;
			if count == Face.MAX_POINTS - 1 {
				if token[0] == #char"#" break;
				return .{type=.INVALID};
			}
			vts[count] = parse_vertice(token);
			t := vts[count].type;
			if t == .INVALID {
				return .{type=.INVALID};
			}
			count += 1;
		}
		if count < 3 return .{type=.INVALID};	
		face := Face.{type = vts[0].type, count = count};
		for i : 0..count-1 {
			for j : 0..2 {
				if vts[i].type != face.type return .{type=.INVALID};
				face.ids[i * 3 + j] = vts[i].ids[j];
			}
		}
		return face;
	}
	fix_ids :: (f : *Face, l : [3]int) -> bool {
		for j : 0..2 {
			if (cast(s64) f.type) & (1 << j) {
				for i : 0..f.count-1 {
					id := f.ids[i * 3 + j];
					id = ifx id < 0 then l[j] + id else id - 1;
					if id < 0 || id >= l[j] return false;
					f.ids[i * 3 + j] = id;
				}
			} else {
				for i : 0..f.count-1 f.ids[i * 3 + j] = -1;
			}
		}
		return true;
	}

	line_id := 0;
	while 1 {
		line_id += 1;
		line, ok_line := parse_token(*obj_view, "", "\n");
		if !ok_line break;

		prefix, ok_pref := parse_token(*line); if !ok_pref continue;

		if prefix == {
			case "v";
			pos : vec3; ok_v : bool;
			pos, ok_v = parse_vec(*line, vec3); end(ok_v, "(0)");
			array_add(*points, pos);

			case "vt";
			uv, ok_vt := parse_vec(*line, vec2); end(ok_vt, "(1)");
			array_add(*uvs, uv);

			case "vn";
			pos, ok_vn := parse_vec(*line, vec3); end(ok_vn, "(2)");
			array_add(*normals, pos);

			case "f";
			face := parse_face(*line); end(face.type != .INVALID, "(3)");

			ls : [3]int; ls[0], ls[1], ls[2] = points.count, uvs.count, normals.count;
			end(fix_ids(*face, ls), "(4)");

			most_general |= face.type;
			array_add(*faces, face);

			case "o"; #through;
			case "g"; #through;
			case "s"; #through;
			case "mtllib"; #through;
			case "usemtl";
			print("prefix % not supported yet\n", prefix);

			case;
			end(prefix[0] == #char "#", "(5)");
			continue;
		}
	}
	return .{points=points, uvs=uvs, normals=normals, faces=faces, most_general=most_general}, true;
}

prepare :: (mesh : *Mesh_Raw_SOA, default_uv := vec2.{0, 0}, default_normal := vec3.{0, 0, 0}) -> int {
	add_smooth_normals := false;
	add_flat_normals := true;

	if mesh.gl_ready return 1;
	// if add_flat_normals && (mesh.most_general & .N & 6) return 2;

	cm_cmp :: (x : $T, y : T) -> bool {
		S := size_of(T);
		xp := cast(*u8)*x;
		yp := cast(*u8)*y;
		for 0..S-1 if xp[it] != yp[it] return false;
		return true;
	}
	cm_hash :: (x : $T) -> u32 {
		return inline sdbm_hash(xx *x, size_of(T), 5381);
	}
	Triplet :: struct { p, uv, n : int; };
	get_trplet :: (f : Face, i : int) -> Triplet {
		return .{f.ids[i * 3], f.ids[i * 3 + 1], f.ids[i * 3 + 2]};
	}
	Vid :: struct { count, id : int; norm_sum : vec3; };

	unique_points : Table(Triplet, Vid, cm_hash, cm_cmp);
	init(*unique_points); defer deinit(*unique_points);

	points_count := 0;
	for f : mesh.faces {
		points_count += 3 * (f.count - 2);
		fpoints : [Face.MAX_POINTS]vec3;
		vptrs : [Face.MAX_POINTS]*Vid;
		for i : 0..f.count-1 {
			fpoints[i] = mesh.points[f.ids[3 * i]];
			is_new : bool;
			vptrs[i], is_new = find_or_add(*unique_points, get_trplet(f, i));
			if is_new {
				<<vptrs[i] = .{1, unique_points.count - 1, vec3.{}};
			} else {
				vptrs[i].count += 1;
			}
		}
		for i : 1..f.count-2 {
			n := normalize
				(cross(fpoints[0] - fpoints[i], fpoints[0] - fpoints[i + 1]));
			vptrs[0].norm_sum += n;
			vptrs[i].norm_sum += n;
			vptrs[i + 1].norm_sum += n;
		}
	}

	single_point_size := size_of(vec3)
						+ (ifx mesh.most_general & .UV & 6 then size_of(vec2) else 0)
						+ (ifx mesh.most_general & .N & 6 then size_of(vec3) else 0);

	size_with_no_ebo := points_count * single_point_size;
	size_with_ebo := unique_points.count * single_point_size + points_count * size_of(u32);

	// print("size_with_no_ebo: %, size_with_ebo: %\n", size_with_no_ebo, size_with_ebo);
	use_ebo := size_with_ebo < size_with_no_ebo && !add_flat_normals;

	points_new, normals_new : [..]vec3;
	uvs_new : [..]vec2;
	indices : [..]u32;

	if use_ebo {
		array_resize(*points_new, unique_points.count);
		if mesh.most_general & .UV & 6 {
			array_resize(*uvs_new, unique_points.count);
		}
		if (mesh.most_general & .N & 6) || add_smooth_normals {
			array_resize(*normals_new, unique_points.count);
		}
		for v, k : unique_points {
			pos := mesh.points[k.p];
			points_new[v.id] = pos;
			if mesh.most_general & .UV & 6 uvs_new[v.id] = mesh.uvs[k.uv];
			if mesh.most_general & .N & 6 {
				normals_new[v.id] = mesh.normals[k.n];
			} else if add_smooth_normals {
				normals_new[v.id] = normalize(v.norm_sum);
			}
		}
		array_reserve(*indices, points_count);
		for f : mesh.faces {
			ids : [Face.MAX_POINTS]u32;

			for i : 0..f.count-1 {
				vid, ok := table_find(*unique_points, .{f.ids[i * 3], f.ids[i * 3 + 1], f.ids[i * 3 + 2]});
				ids[i] = xx vid.id;
			}

			for i : 1..f.count-2 {
				array_add(*indices, ids[0]);
				array_add(*indices, ids[i]);
				array_add(*indices, ids[i + 1]);
			}
		}
	} else {
		array_reserve(*points_new, points_count);
		if mesh.most_general & .UV & 6 {
			array_reserve(*uvs_new, points_count);
		}
		if (mesh.most_general & .N & 6) || add_smooth_normals || add_flat_normals {
			array_reserve(*normals_new, points_count);
		}

		add_point :: (f : Face, i : u32/*, n_flat := vec3.{}*/) #expand {
			array_add(*`points_new, `mesh.points[f.ids[i * 3]]);
			if `mesh.most_general & .UV & 6 array_add(*`uvs_new, `mesh.uvs[f.ids[i * 3 + 1]]);
			if mesh.most_general & .N & 6 {
				array_add(*`normals_new, `mesh.normals[f.ids[i * 3 + 2]]);
			} else if add_smooth_normals {
				vid, ok := table_find(*`unique_points, get_trplet(f, i));
				array_add(*`normals_new, vid.norm_sum);
			} else if add_flat_normals {
				array_add(*`normals_new, .{});
			}
		}

		for f : mesh.faces {
			for i : 1..f.count-2 {
				add_point(f, 0);
				add_point(f, i);
				add_point(f, i + 1);
				if add_flat_normals {
					C := points_new.count;
					p0, p1, p2 := points_new[C - 3], points_new[C - 2], points_new[C - 1];
					n := normalize(cross(p0 - p1, p0 - p2));
					normals_new[C - 3], normals_new[C - 2], normals_new[C - 1] = n;
				}
			}
		}
	}

	array_free(mesh.points); mesh.points = points_new;
	array_free(mesh.uvs); mesh.uvs = uvs_new;
	array_free(mesh.normals); mesh.normals = normals_new;
	array_free(mesh.faces); mesh.indices = indices;

	mesh.gl_ready = true;

	return 0;
}

// usage_example :: () {
// 	mesh_raw_soa, ok := load_obj("6th_platonic_solid.obj");
// 	// This method ignores spaces in the faces declaration.
// 	// For example, "f 1 / 2/3  4/ 5/ 6 2/3  / 4" will be parsed as well, as "f 1/2/3 4/5/6 2/3/4" even though the .obj spec says it's an error.
// 	if !ok exit(1);
// 	prepare(*mesh_raw_soa);
// 	// Since some triangles may not have a UV coordinate or normal vector specified,
// 	// this method adds them (only if at least one triangle has a normal/uv coordinate).
// 	// Also, it replaces the array of triangles with an array of indices for glDrawElements.
// 	// If some of the vertices do not have the same set of indices,
// 	// then the vertices are duplicated for rendering using glDrawArrays.

// 	// for debug print you can use print_mesh_raw_soa(). it produces different output if mesh prepared for render.
// 	defer clear_mesh_raw(mesh_raw_soa);	
// }