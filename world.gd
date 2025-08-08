extends Node4D

## You must format the off file to start with the vertex count, then in the next line the face count. It should not begin with #5OFF or whatever, and it should have markers for where the vertices and faces start, like # Faces. Also, it doesn't work if the vertices in the face aren't in a winding order.
func import_5D_off(file_path: String) -> Mesh5D:
	var mesh := Mesh5D.new()
	
	var off := FileAccess.open(file_path, FileAccess.READ)
	
	var text := off.get_as_text()
	
	var lines := text.split("\n")
	
	var vert_count := int(lines[0])
	var face_count := int(lines[1])
	
	var mode := 0
	
	for line in lines:
		match mode:
			1:
				if mesh.vertices_v.size() != vert_count:
					var vertices_text = line.split(" ")
					var vertices = []
					for vert in vertices_text:
						vertices.append(float(vert))
					mesh.vertices_xyzw.append(Vector4(vertices[0], vertices[1], vertices[2], vertices[3]))
					mesh.vertices_v.append(vertices[4])
			2:
				if line == "":
					break
				else:
					var face_text := line.split(" ")
					var face = []
					for vert_id in face_text:
						face.append(int(vert_id))
					face.remove_at(0)
					
					for id in face.size() - 2:
						mesh.triangles.append(face[0])
						mesh.triangles.append(face[id + 1])
						mesh.triangles.append(face[id + 2])
		
		if line == "# Vertices":
			mode = 1
		if line == "# Faces":
			mode = 2
	
	return mesh
