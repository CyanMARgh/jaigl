#import "Random";
#import "File";
#import "String";

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


Face :: struct {
	// [3]coord + ([3]uv) + ([3]normal)
	type : Ftype;
	Ftype :: enum_flags u8 {
		P       :: 0b_001;
		UV      :: 0b_011;
		N       :: 0b_101;
		UVN     :: 0b_111;
		INVALID :: 0b_000;
	};
	ids : [9]int;
}
size :: (f : Face) -> s64 {
	if #complete f.type == {
		case .P;
		return 1;
		case .UV;
		return 2;
		case .N;
		return 2;
		case .UVN;
		return 3;
		case .INVALID;
		return 0;
	}
}
Mesh_Raw_SOA :: struct {
	points  : []vec3;
	uvs     : []vec2; //TODO replace with uvw
	normals : []vec3;
	union {
		faces : []Face;
		indices : []u32;
	}
	most_general := Face.Ftype.INVALID;
	splitted_vertices := false;
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
			if type == {
				case .P;
				print("f % % %\n", ids[0], ids[3], ids[6]);
				case .UV;
				print("f %/% %/% %/%\n", ids[0], ids[1], ids[3], ids[4], ids[6], ids[7]);
				case .N;
				print("f %//% %//% %//%\n", ids[0], ids[2], ids[3], ids[5], ids[6], ids[8]);
				case .UVN;
				print("f %/%/% %/%/% %/%/%\n", ids[0], ids[1], ids[2], ids[3], ids[4], ids[5], ids[6], ids[7], ids[8]);
			}
		}
	} else {
		for t : 0..(indices.count/3-1) {
			print("f [% % %]\n", mesh.indices[t * 3], mesh.indices[t * 3 + 1], mesh.indices[t * 3 + 2]);
		}
	}
	print("\npoints: %, uvs: %, normals: %, faces: %\nis_spliied: %\ntype: %\n", points.count, uvs.count, normals.count, faces.count, splitted_vertices, most_general);
}
clear_mesh_raw :: (using mesh : Mesh_Raw_SOA) {
	array_free(points);
	array_free(uvs);
	array_free(normals);
	array_free(faces);
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
	splitted_vertices := false;
	most_general := Face.Ftype.INVALID;

	check_if_splitted :: (f : Face, sv : *bool) {
		if <<sv return;
		s := size(f);
		if f.type & .UV & 6 {
			<<sv |= f.ids[0] != f.ids[1] || f.ids[3] != f.ids[4] || f.ids[6] != f.ids[7];
		}
		if f.type & .N & 6 {
			<<sv |= f.ids[0] != f.ids[2] || f.ids[3] != f.ids[5] || f.ids[6] != f.ids[8];
		}
	}

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

	parse_face :: (str : *string) -> Face {
		ids : [15]int;
		ids2 : [9]int;
		code : u64 = 0;

		for i : 0..15 {
			token, ok_t := parse_token(str, "/");
			if !ok_t break;
			if i == 15 {
				if token[0] != #char "#" return .{type = .INVALID};
				break;
			} else if token == "/" {
				code = (code << 2) | 0b10;
			} else {
				id, ok_id := string_to_int(token);
				if !ok_id return .{type = .INVALID};

				ids[i] = id;
				code = (code << 2) | 0b11;
			}
		}

		if code == {
			case 0b___11_11_11;
			ids2[0], ids2[3], ids2[6] = ids[0], ids[1], ids[2];
			return .{.P, ids2};
			case 0b___111011_111011_111011;
			ids2[0], ids2[1], ids2[3], ids2[4], ids2[6], ids2[7] = ids[0], ids[2], ids[3], ids[5], ids[6], ids[8];
			return .{.UV, ids2};
			case 0b___11101011_11101011_11101011;
			ids2[0], ids2[2], ids2[3], ids2[5], ids2[6], ids2[8] = ids[0], ids[3], ids[4], ids[7], ids[8], ids[11];
			return .{.N, ids2};
			case 0b___1110111011_1110111011_1110111011;
			ids2[0], ids2[1], ids2[2], ids2[3], ids2[4], ids2[5], ids2[6], ids2[7], ids2[8] = ids[0], ids[2], ids[4], ids[5], ids[7], ids[9], ids[10], ids[12], ids[14];
			return .{.UVN, ids2};
			case;
			return .{type = .INVALID};
		}
	}
	fix_ids :: (f : *Face, l : [3]int) -> bool {
		for j : 0..2 {
			if !((cast(s64) f.type) & (1 << j)) continue;
			for i : 0..2 {
				id := f.ids[i * 3 + j];
				id = ifx id < 0 then l[j] + id else id - 1;
				if id < 0 || id >= l[j] {
					return false;
				}
				f.ids[i * 3 + j] = id;
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

			check_if_splitted(face, *splitted_vertices);
			most_general |= face.type;
			array_add(*faces, face);

			case "o"; #through;
			case "g"; #through;
			case "s"; #through;
			case "mtllib"; #through;
			case "usrmtl";
			print("prefix % not supported yet\n", prefix);

			case;
			end(prefix[0] == #char "#", "(5)");
			continue;
		}
	}
	return .{points=points, uvs=uvs, normals=normals, faces=faces, splitted_vertices=splitted_vertices, most_general=most_general}, true;
}

prepare :: (mesh : *Mesh_Raw_SOA, default_uv := vec2.{0, 0}, default_normal := vec3.{0, 0, 0}) {
	if mesh.gl_ready {
		print("mesh already marked as ready!\n");
		return;
	}
	if mesh.splitted_vertices {
		points_new, normals_new : []vec3;
		uvs_new : []vec2;
		points_new = NewArray(mesh.faces.count * 3, vec3);
		if mesh.most_general & .UV & 6 {
			uvs_new = NewArray(mesh.faces.count * 3, vec2);
		}
		if mesh.most_general & .N & 6 {
			normals_new = NewArray(mesh.faces.count * 3, vec3);
		}

		for f, i : mesh.faces {
			for j : 0..2 {
				uv := default_uv; n := default_normal;
				p := mesh.points[f.ids[j * 3]];
				if f.type & .UV & 6 then uv = mesh.uvs[f.ids[j * 3 + 1]];
				if f.type & .N & 6 then n = mesh.normals[f.ids[j * 3 + 2]];

				points_new[i * 3 + j] = p;
				if mesh.most_general & .UV & 6 then uvs_new[i * 3 + j] = uv;
				if mesh.most_general & .N & 6 then normals_new[i * 3 + j] = n;
			}
		}
		array_free(mesh.points);
		array_free(mesh.uvs);
		array_free(mesh.normals);
		array_free(mesh.faces);

		mesh.points = points_new;
		mesh.uvs = uvs_new;
		mesh.normals = normals_new;
		mesh.indices = .[];
	} else {
		ids_new := NewArray(mesh.faces.count * 3, u32);
		for f, i : mesh.faces {
			ids_new[i * 3], ids_new[i * 3 + 1], ids_new[i * 3 + 2] = cast(u32) f.ids[0], cast(u32) f.ids[3], cast(u32) f.ids[6];
		}
		array_free(mesh.faces);
		mesh.indices = ids_new;
	}
	mesh.gl_ready = true;
	// defer clear_mesh_raw(mesh);
	// return .{};
}

usage_example :: () {
	mesh_raw_soa, ok := load_obj("6th_platonic_solid.obj");
	// This method ignores spaces in the faces declaration.
	// For example, "f 1 / 2/3  4/ 5/ 6 2/3  / 4" will be parsed as well, as "f 1/2/3 4/5/6 2/3/4" even though the .obj spec says it's an error.
	if !ok exit(1);
	prepare(*mesh_raw_soa);
	// Since some triangles may not have a UV coordinate or normal vector specified,
	// this method adds them (only if at least one triangle has a normal/uv coordinate).
	// Also, it replaces the array of triangles with an array of indices for glDrawElements.
	// If some of the vertices do not have the same set of indices,
	// then the vertices are duplicated for rendering using glDrawArrays.

	// for debug print you can use print_mesh_raw_soa(). it produces different output if mesh prepared for render.
	defer clear_mesh_raw(mesh_raw_soa);	
}