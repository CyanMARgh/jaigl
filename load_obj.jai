// TODO separate "opengl" scene/mesh and obj file

rect_src :: Mesh_Raw.{
	points = .[
		-1, -1, 0,     0, 0,
		 1, -1, 0,     1, 0,
		 1,  1, 0,     1, 1,
		-1,  1, 0,     0, 1
	],
	indices = .[0, 1, 2, 0, 2, 3]
};


Point :: struct {
	pos : Vector3;
}
Point_UV :: struct {
	pos : Vector3;
	uv : Vector2;
}
Point_UV_N :: struct {
	pos : Vector3;
	uv : Vector2;
	n : Vector3;	
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
	points   : []Vector3;
	uvs      : []Vector2;
	normals  : []Vector3;
	tangents : []Vector3;
	binormals: []Vector3;
	union {
		faces : []Face;
		indices : []u32;
	}
	most_general := Ftype.INVALID;
	gl_ready := false;
}
print_mesh_raw_soa :: (using mesh : Mesh_Raw_SOA) {
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
	print("points: %, uvs: %, normals: %, faces/indices: %\ntype: %\ngl_ready: %\n\n",
		points.count, uvs.count, normals.count, faces.count, most_general, gl_ready);
}
clear_mesh_raw :: (using mesh : Mesh_Raw_SOA) {
	array_free(points);
	array_free(uvs);
	array_free(normals);
	array_free(tangents);
	array_free(binormals);
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

	points : [..]Vector3;
	uvs : [..]Vector2;
	normals : [..]Vector3;
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
			pos : Vector3; ok_v : bool;
			pos, ok_v = parse_vec(*line, Vector3); end(ok_v, "(0)");
			array_add(*points, pos);

			case "vt";
			uv, ok_vt := parse_vec(*line, Vector2); end(ok_vt, "(1)");
			array_add(*uvs, uv);

			case "vn";
			pos, ok_vn := parse_vec(*line, Vector3); end(ok_vn, "(2)");
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

prepare :: (mesh : *Mesh_Raw_SOA, default_uv := Vector2.{0, 0}, default_normal := Vector3.{0, 0, 0}) -> int {
	add_smooth_normals := true;
	add_flat_normals := false;

	if mesh.gl_ready return 1;
	// if add_flat_normals && (mesh.most_general & .N & 6) return 2;

	triplet_cmp :: (x : [3]int, y : [3]int) -> bool {
		return x[0] == y[0] && x[1] == y[1] && x[2] == y[2];
	}
	triplet_hash :: (x : [3]int) -> u32 {
		return inline sdbm_hash(xx *x, size_of(int) * 3, 5381);
	}
	get_trplet :: (f : Face, i : int) -> [3]int {
		res : [3]int;
		res[0], res[1], res[2] = f.ids[i * 3], f.ids[i * 3 + 1], f.ids[i * 3 + 2];
		return res;
	}

	Unique_Point :: struct { id : int; nsum : Vector3; }

	unique_points : Table([3]int, Unique_Point, triplet_hash, triplet_cmp);
	init(*unique_points); defer deinit(*unique_points);

	points_count := 0;
	for f : mesh.faces {
		points_count += 3 * (f.count - 2);
		vert_ids : [Face.MAX_POINTS]*Unique_Point;
		corners : [Face.MAX_POINTS]Vector3;

		for i : 0..f.count-1 {
			triplet := get_trplet(f, i);
			vert_id_ptr, is_new := find_or_add(*unique_points, triplet);
			if is_new {
				<<vert_id_ptr = .{id = unique_points.count - 1};
			}
			corners[i] = mesh.points[triplet[0]];
		}
		for i : 0..f.count-1 vert_ids[i] = table_find_pointer(*unique_points, get_trplet(f, i));

		for i : 1..f.count-2 {
			e01 := normalize(corners[i] - corners[0]);
			e12 := normalize(corners[i + 1] - corners[i]);
			e20 := normalize(corners[0] - corners[i + 1]);

			weighted_normal :: (u : Vector3, v : Vector3) -> Vector3 {
				return cross(u, v);
			}

			vert_ids[0].nsum	 += weighted_normal(e20, e01);
			vert_ids[i].nsum	 += weighted_normal(e01, e12);
			vert_ids[i + 1].nsum += weighted_normal(e12, e20);
		}
	}

	single_point_size := size_of(Vector3)
						+ (ifx mesh.most_general & .UV & 6 then size_of(Vector2) else 0)
						+ (ifx mesh.most_general & .N & 6 then size_of(Vector3) else 0);

	size_with_no_ebo := points_count * single_point_size;
	size_with_ebo := unique_points.count * single_point_size + points_count * size_of(u32);

	// print("size_with_no_ebo: %, size_with_ebo: %\n", size_with_no_ebo, size_with_ebo);
	use_ebo := size_with_ebo < size_with_no_ebo && !add_flat_normals;
	print("use_ebo = %\n", use_ebo);

	points_new, normals_new : [..]Vector3;
	uvs_new : [..]Vector2;
	indices : [..]u32;

	if use_ebo {
		array_resize(*points_new, unique_points.count);
		if mesh.most_general & .UV & 6 {
			array_resize(*uvs_new, unique_points.count);
		}
		if (mesh.most_general & .N & 6) || add_smooth_normals {
			array_resize(*normals_new, unique_points.count);
		}
		for vert, triplet : unique_points {
			pos := mesh.points[triplet[0]];
			points_new[vert.id] = pos;
			if mesh.most_general & .UV & 6 uvs_new[vert.id] = mesh.uvs[triplet[1]];
			if mesh.most_general & .N & 6 {
				normals_new[vert.id] = mesh.normals[triplet[2]];
			} else if add_smooth_normals {
				normals_new[vert.id] = normalize(vert.nsum);
			}
		}
		array_reserve(*indices, points_count);
		for f : mesh.faces {
			ids : [Face.MAX_POINTS]u32;

			for i : 0..f.count-1 {
				vert, ok := table_find(*unique_points, get_trplet(f, i)); if !ok exit(1);
				ids[i] = xx vert.id;
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

		add_point :: (f : Face, i : u32/*, n_flat := Vector3.{}*/) #expand {
			array_add(*`points_new, `mesh.points[f.ids[i * 3]]);
			if `mesh.most_general & .UV & 6 array_add(*`uvs_new, `mesh.uvs[f.ids[i * 3 + 1]]);
			if mesh.most_general & .N & 6 {
				array_add(*`normals_new, `mesh.normals[f.ids[i * 3 + 2]]);
			} else if `add_smooth_normals {
				vert, ok := table_find(*`unique_points, get_trplet(f, i)); if !ok exit(1);
				array_add(*`normals_new, normalize(vert.nsum));
			} else if `add_flat_normals {
				corners : [3]Vector3;
				for i : 0..2 corners[i] = mesh.points[f.ids[i * 3]];
				n := normalize(cross(corners[1] - corners[0], corners[2] - corners[0]));
				array_add(*`normals_new, n);
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
