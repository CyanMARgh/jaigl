Material :: struct {
	// Despite the fact that this is vec4, the 4th component is needed only for the convenience of binding to the shader and for nothing more.
	ambient_color : vec4; 			// Ka
	diffuse_color : vec4; 			// Kd
	specular_color : vec4;			// Ks
	specular_highlights : float = 1;// Ns
	optical_density : float = 1;	// Ni
	dissolve : float = 1;			// d
	emission : vec4;				// Ke
	illumination_model : u32 = 0;   // illum
}

Named_Material :: struct {
	name : string;
	using base : Material;
}
File_MTL :: struct {
	materials : []Named_Material;
}
clear_file_mtl :: (file : *File_MTL) {
	for file.materials free(it.name);
	array_free(file.materials);
} 

load_mtl :: (mtl_path : string) -> File_MTL, bool {
	materials : [..]Named_Material;
	mtl_data, success := read_entire_file(mtl_path);
	mtl_view := mtl_data;
	if !success {
		print("couldn't load file: %\n", mtl_path);
		return .{}, false;
	} 
	defer free(mtl_data);

	temp_mat : Named_Material;
	new_material :: (name : string) #expand {
		if temp_mat.name != "" {
			array_add(*materials, temp_mat);
		}
		temp_mat = .{name = copy_string(name)};
	}
	clear_materials :: () #expand {
		for `materials free(it.name);
		array_free(`materials);
	}
	end :: (ok := false, reason := "?") #expand {
		if !ok {
			print("failed to parse file %, line: %\nreason: %\n", `mtl_path, `line_id, reason);
			clear_materials();
			`return .{}, false;
		}
	}

	parse_vec3 :: (lptr : *string) -> vec4, bool {
		v : vec4; ok : bool;
		v.x, ok = parse_float(lptr); if !ok return .{}, false;
		v.y, ok = parse_float(lptr); if !ok return .{}, false;
		v.z, ok = parse_float(lptr); if !ok return .{}, false;
		t, t_ok:= parse_token(lptr); if t_ok && t[0] != #char"#" return .{}, false;
		return v, true;
	}
	field_vec3 :: (field : *vec4, lptr : *string) #expand {
		ok : bool;
		<<field, ok = parse_vec3(lptr);
		if !ok {
			print("failed to parse file %, line: %\nreason: %\n", `mtl_path, `line_id, "wrong vec3 format");
			clear_materials();
			`return .{}, false;
		}
	}
	field_float :: (field : *float, lptr : *string) #expand {
		ok : bool;
		<<field, ok = parse_float(lptr);
		l2, ok2 := parse_token(lptr); 
		if !ok || (ok2 && l2[0] != #char"#") {
			print("failed to parse file %, line: %\nreason: %\n", `mtl_path, `line_id, "wrong float format");
			clear_materials();
			`return .{}, false;
		}
	}
	field_int :: (field : *u32, lptr : *string) #expand {
		ok : bool; il : int;
		il, ok = parse_int(lptr);
		<<field = xx il;
		l2, ok2 := parse_token(lptr); 
		if !ok || (ok2 && l2[0] != #char"#") {
			print("failed to parse file %, line: %\nreason: %\n", `mtl_path, `line_id, "wrong float format");
			clear_materials();
			`return .{}, false;
		}
	}

	line_id := 0;
	while 1 {
		line, ok_line := parse_token(*mtl_view, "\n", "");
		if !ok_line break;
		if line == "\n" { line_id += 1; continue; }

		prefix := parse_token(*line);
		ok : bool;
		if prefix == {
			case "newmtl";
			name, ok_name := parse_token(*line); end(ok_name, "no name set");
			new_material(name);

			case "Ka"; field_vec3(*temp_mat.ambient_color, *line);
			case "Kd"; field_vec3(*temp_mat.diffuse_color, *line);
			case "Ks"; field_vec3(*temp_mat.specular_color, *line);
			case "Ke"; field_vec3(*temp_mat.emission, *line);

			case "Ni"; field_float(*temp_mat.optical_density, *line);
			case "d"; field_float(*temp_mat.dissolve, *line);
			case "Ns"; field_float(*temp_mat.specular_highlights, *line);

			case "illum"; field_int(*temp_mat.illumination_model, *line);

			case;
			if prefix[0] == #char"#" continue;
			print("failed to parse file %, at line %\nreason : unknown prefix (%)", mtl_path, line_id, prefix);
			return .{}, false;
		}

	}
	array_add(*materials, temp_mat);

	return .{materials}, true;
}

// TODO
// mesh_raw_soa -> Obj_File_Scene
