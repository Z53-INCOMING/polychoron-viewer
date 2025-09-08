@icon("res://Icons/Model4D.png")
## Stores a wireframe 4D model. Has over 500 lines of model utility functions. This is a very general purpose class, so if you want to create a specific shape look for it under Node4D. If it exists it will be rendered with cell occlusion and other special stuff. Texturing: To make a model a texture, make sure its flat and on the XYZ volume. Also make sure it's values are between -0.5 and 0.5. Scaling: This engine wasn't built to handle large objects. Make sure that two vertices of an edge are never more than a unit and a half apart or so. If you need big things, use the subdivide_edges() function a couple times.
class_name Model

## Saves the model as a .tres resource to the project file folder. (more specifically res://Meshes/) Don't use in a place where the player would run the command, as res:// becomes a read-only directory after the project is exported. If the model is meant to be a texture, use "Textures/Name".
static func save(mesh: ArrayWireMesh4D, name: String):
	var path = "res://" + name + ".tres"
	
	ResourceSaver.save(mesh, path)

## Creates a line.
static func create_line(mesh: ArrayWireMesh4D, a: Vector4, b: Vector4):
	mesh.append_edge_points(a, b)

## Merges two meshes.
static func merge_meshes(mesh_a: ArrayWireMesh4D, mesh_b: ArrayWireMesh4D, mesh_b_offset: Vector4, mesh_b_matrix: Projection) -> ArrayWireMesh4D:
	var output_mesh: ArrayWireMesh4D = mesh_a.duplicate(true)
	
	for vertex in mesh_b.get_vertices():
		output_mesh.append_vertex((mesh_b_matrix * vertex) + mesh_b_offset, false)
	
	var mesh_b_edges := mesh_b.get_edge_indices()
	var number_of_vertices_in_mesh_a := mesh_a.get_vertices().size()
	for i in range(mesh_b_edges.size(), 2):
		output_mesh.append_edge_indices(mesh_b_edges[i] + number_of_vertices_in_mesh_a, mesh_b_edges[i + 1] + number_of_vertices_in_mesh_a)
	
	#var new_material := WireMaterial4D.new()
	#
	#new_material.albedo_color_array.append_array(mesh_a.material.albedo_color_array)
	#new_material.line_thickness := 
	
	return output_mesh

## Very naive implementation of an OFF file importer. I recommend making the extension .txt so its visible in the Godot editor. Also here are some of the things to keep in mind if it fails: The line that contains the number of points, edges, faces and cells of the model MUST be on the second line. Second, make sure no comments contain the word "vertices" or "faces", except for the ones that mark the start of the vertices and faces. And another thing, make sure there's a comment that says faces and a comment that says vertices directly before the vertices and faces block. My function can't tell if that block has started without it.
static func import_off(name: String, file_extension = ".txt", scale = 1.0, dimensions = 4) -> ArrayWireMesh4D:
	var mesh := ArrayWireMesh4D.new()
	var file = FileAccess.open("res://OFF/" + name + file_extension, FileAccess.READ)
	
	var mode = 0 # 0 is none, 1 is vertex mode, and 2 is edge connection mode
	
	var vertex_count = 0
	var face_count = 0
	
	var index = 0
	
	while face_count > -1:
		#if file.eof_reached():
			#continue
		
		var line = file.get_line()
		
		if index == 1:
			var array = line.split(" ")
			
			if array.size() == dimensions:
				vertex_count = int(array[0])
				face_count = int(array[1])
		
		match mode:
			1:
				vertex_count -= 1
				if vertex_count >= 0:
					var array = line.split(" ")
					
					var vector = Vector4(
						float(array[0]),
						float(array[1]),
						float(array[2]) if dimensions >= 3 else 0.0,
						float(array[3]) if dimensions == 4 else 0.0
					)
					
					mesh.append_vertex(vector * scale, false)
			2:
				face_count -= 1
				if face_count >= 0:
					var array = line.split(" ")
					var last = int(array[0]) - 1
					array.remove_at(0)
					if array.size() != last + 1:
						continue
					
					var polygon = []
					for i in array:
						polygon.append(int(i))
					
					for i in polygon.size():
						if !check_edge(mesh, [polygon[i], polygon[0 if i == last else i + 1]]):
							mesh.append_edge_indices(polygon[i], polygon[0 if i == last else i + 1])
		
		if "vertices" in line.to_lower():
			mode = 1
		
		if "faces" in line.to_lower():
			mode = 2
		
		index += 1
	return mesh

## Adds a point in the middle of each edge and reconnects everything.
static func subdivide_edges(mesh: ArrayWireMesh4D):
	var edge_indices: PackedInt32Array = mesh.edge_indices
	var vertices: PackedVector4Array = mesh.vertices
	var original_edge_indices_size = edge_indices.size()
	for i in range(0, original_edge_indices_size, 2):
		var new_vert_index: int = mesh.append_vertex((vertices[edge_indices[i]] + vertices[edge_indices[i + 1]]) * 0.5, false)
		edge_indices.append(new_vert_index)
		edge_indices.append(edge_indices[i + 1])
		edge_indices[i + 1] = new_vert_index
		
		if mesh.material.albedo_source != WireMaterial4D.WIRE_COLOR_SOURCE_SINGLE_COLOR:
			mesh.material.append_albedo_color(mesh.material.get_albedo_color_array()[i / 2])
	mesh.edge_indices = edge_indices


## Subdivides one edge a specific number of times.
static func specific_subdivide(mesh: ArrayWireMesh4D, edge_id: int, subdivisions: int):
	var original_edge_a = mesh.edge_indices[edge_id * 2]
	var original_edge_b = mesh.edge_indices[edge_id * 2 + 1]
	var points_along_edge = [original_edge_a]
	#var second_point = edges[edge_id][1]
	mesh.edge_indices.remove_at(edge_id * 2)
	mesh.edge_indices.remove_at(edge_id * 2)
	
	for i in subdivisions:
		mesh.append_vertex(lerp(mesh.vertices[original_edge_a], mesh.vertices[original_edge_b], (1.0 / float(subdivisions + 1)) * (i + 1)), false)
		points_along_edge.append(mesh.vertices.size() - 1)
	
	points_along_edge.append(original_edge_b)
	
	for i in points_along_edge.size() - 1:
		mesh.append_edge_indices(points_along_edge[i], points_along_edge[i + 1])


## Puts every vertex at the same distance to the origin.
static func normalize_vertex_distances(mesh: ArrayWireMesh4D, distance = 1.0):
	var vertices = mesh.vertices
	for i in vertices.size():
		vertices[i] = vertices[i].normalized() * distance
	mesh.vertices = vertices


## Creates a duoprism using two regular polygons specified with radius and quality. Don't use filled, it's a work in progress.
static func create_duoprism(mesh: ArrayWireMesh4D, quality_1 = 32, quality_2 = 32, radius_1 = 0.5, radius_2 = 0.5, filled = false):
	var angle = 0.0
	var wind = TAU / float(quality_1)
	#var start_point = points.size()
	
	for i in quality_1 + (1 if filled else 0):
		var x = cos(angle) * radius_1
		var y = sin(angle) * radius_1
		create_polygon(mesh, quality_2, radius_2, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(x, y, 0, 0), filled)
		
		for e in quality_2:
			var new_e = (e if filled else e)
			if i == 0:
				mesh.append_edge_indices(new_e, (new_e + ((quality_1 - 1) * quality_2)))
			else:
				mesh.append_edge_indices((mesh.vertices.size() - (new_e + 1)), (mesh.vertices.size() - (new_e + quality_2 + 1)))
		
		angle += wind

static func create_star_duoprism(mesh: ArrayWireMesh4D, quality_1 = 32, quality_2 = 32, skip_1 = 2, skip_2 = 2, radius_1 = 0.5, radius_2 = 0.5):
	var angle = 0.0
	var wind = TAU / float(quality_1)
	#var start_point = points.size()
	
	for i in quality_1:
		var x = cos(angle) * radius_1
		var y = sin(angle) * radius_1
		create_stellated_polygon(mesh, quality_2, skip_2, radius_2, Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1), Vector4(x, y, 0, 0))
		
		for e in quality_2:
			if i == 0:
				mesh.append_edge_indices(e, (e + ((quality_1 - 1) * quality_2)))
			else:
				mesh.append_edge_indices((mesh.vertices.size() - (e + 1)), (mesh.vertices.size() - (e + quality_2 + 1)))
		
		angle += wind * skip_1

## Creates a duoprism where both polygons are the same. Don't use filled, its a work in progress.
static func create_duocylinder(mesh: ArrayWireMesh4D, radius_1 = 0.5, radius_2 = 0.5, quality = 32, filled = false):
	create_duoprism(mesh, quality, quality, radius_1, radius_2, filled)


## Extrudes the model to a vertex on the Y axis with the height of height.
static func pyramid(mesh: ArrayWireMesh4D, height = 2.0):
	for p in mesh.vertices.size():
		mesh.append_edge_indices(p, mesh.vertices.size())
	mesh.append_vertex(Vector4(0, height, 0, 0), false)

## Insets the last last_points points. See inset_side for function details.
static func inset_last(mesh: ArrayWireMesh4D, last_points: int, inset_ratio = 0.5):
	inset_side(mesh, range(mesh.vertices.size() - last_points, mesh.vertices.size()), inset_ratio)

## Creates a side at the same position of the selected side but slightly smaller, and with their vertices connected to the original side. Google "Blender inset face" for a visual explanation. For "inset_ratio", 1.0 is a fully inset facet, and 0.0 is a duplicated facet.
static func inset_side(mesh: ArrayWireMesh4D, vertices_of_side: Array, inset_ratio = 0.5):
	var side_position = Vector4.ZERO
	var edge_indices: PackedInt32Array = mesh.edge_indices
	var vertices: PackedVector4Array = mesh.vertices
	
	for v in vertices_of_side:
		side_position += vertices[v]
	
	side_position /= vertices_of_side.size()
	
	var side_connections = []
	
	for i in range(0, edge_indices.size(), 2):
		if edge_indices[i] in vertices_of_side and edge_indices[i + 1] in vertices_of_side: # checks if edge is between two points in the side we are insetting
			side_connections.append(vertices_of_side.find(edge_indices[i]))
			side_connections.append(vertices_of_side.find(edge_indices[i + 1]))
	
	var original_size = vertices.size()
	for v in vertices_of_side:
		vertices.append(lerp(vertices[v], side_position, inset_ratio))
		edge_indices.append(v)
		edge_indices.append(vertices.size() - 1)
	
	for e in side_connections:
		edge_indices.append(e + original_size)
	mesh.edge_indices = edge_indices
	mesh.vertices = vertices


## Extrudes a side but changes its position by a free Vector4.
static func extrude_side_free(mesh: ArrayWireMesh4D, vertices_of_side: Array, extrusion = Vector4(0.0, 0.0, 0.0, 0.0)):
	var side_connections = []
	var edge_indices: PackedInt32Array = mesh.edge_indices
	for i in range(0, edge_indices.size(), 2):
		if edge_indices[i] in vertices_of_side and edge_indices[i + 1] in vertices_of_side: # checks if edge is between two points in the side we are insetting
			side_connections.append([vertices_of_side.find(edge_indices[i]), vertices_of_side.find(edge_indices[i + 1])])
	var points = mesh.vertices
	var original_size = points.size()
	for v in vertices_of_side:
		points.append(points[v] + extrusion)
		edge_indices.append(v)
		edge_indices.append(points.size() - 1)
	
	for e in side_connections:
		edge_indices.append(e[0] + original_size)
		edge_indices.append(e[1] + original_size)
	mesh.vertices = points
	mesh.edge_indices = edge_indices


## Moves the array of points by a Vector4.
static func move_side_free(mesh: ArrayWireMesh4D, vertices_of_side: Array, movement = Vector4(0.0, 0.0, 0.0, 0.0)):
	var vertices: PackedVector4Array = mesh.vertices
	for v in vertices_of_side:
		vertices[v] += movement
	mesh.vertices = vertices


## Extrudes the last n points along the side's normal. The extrusion will fail if the side's average position is the origin.
static func extrude_last(mesh: ArrayWireMesh4D, previous_count: int, extrusion: float):
	extrude_side_along_normal(mesh, range(mesh.vertices.size() - previous_count, mesh.vertices.size()), extrusion)


## Extrudes the last n points freely.
static func extrude_last_free(mesh:ArrayWireMesh4D, previous_count: int, extrusion: Vector4):
	extrude_side_free(mesh, range(mesh.vertices.size() - previous_count, mesh.vertices.size()), extrusion)


#static func collapse_side_to_point(vertices_of_side: Array):
	#var side_position = Vector4.ZERO
	#
	#for v in vertices_of_side:
		#side_position += points[v]
	#
	#side_position /= vertices_of_side.size()
	#
	#var sorted_list = vertices_of_side.duplicate()
	#sorted_list.sort()
	#sorted_list.reverse()
	#
	#for v in sorted_list:
		#points.remove_at(v)


## Moves a side by a number along its normal. The normal calculation will fail if the side's average position is the origin.
static func move_side_along_normal(mesh: ArrayWireMesh4D, vertices_of_side: Array, movement = 1.0):
	var side_position = Vector4.ZERO
	var vertices: PackedVector4Array = mesh.vertices
	for v in vertices_of_side:
		side_position += vertices[v]
	
	side_position /= vertices_of_side.size()
	
	var normal = side_position.normalized()
	
	mesh.vertices = vertices
	move_side_free(mesh, vertices_of_side, normal * movement)


## The extrusion will fail if the average position of the side is the origin. See also "extrude_side_free"
static func extrude_side_along_normal(mesh: ArrayWireMesh4D, vertices_of_side: Array, extrusion = 1.0):
	var side_position = Vector4.ZERO
	
	for v in vertices_of_side:
		side_position += mesh.vertices[v]
	
	side_position /= vertices_of_side.size()
	
	var normal = side_position.normalized()
	
	extrude_side_free(mesh, vertices_of_side, normal * extrusion)

## Creates a regular polygon.
static func create_polygon(mesh: ArrayWireMesh4D, polygon = 5, vertex_radius = 1.0, x_axis = Vector4(1.0, 0.0, 0.0, 0.0), y_axis = Vector4(0.0, 1.0, 0.0, 0.0), at_position = Vector4.ZERO, central_vertex := false):
	create_stellated_polygon(mesh, polygon, 1, vertex_radius, x_axis, y_axis, at_position, central_vertex)

## Creates a regular polygon but with the top part cut off.
static func create_polygon_sliced(mesh: ArrayWireMesh4D, polygon = 5, skip = 1, vertex_radius = 1.0, x_axis = Vector4(1.0, 0.0, 0.0, 0.0), y_axis = Vector4(0.0, 1.0, 0.0, 0.0), at_position = Vector4.ZERO, central_vertex := false):
	var angle = 0.0
	var wind = TAU / float(polygon)
	var start_point = mesh.vertices.size()
	
	var id = 0
	for i in polygon:
		var x = cos(angle) * vertex_radius
		var y = sin(angle) * vertex_radius
		if y < -0.35:
			mesh.append_vertex(Vector4((x * x_axis.x) + (y * y_axis.x), (x * x_axis.y) + (y * y_axis.y), (x * x_axis.z) + (y * y_axis.z), (x * x_axis.w) + (y * y_axis.w)) + at_position, false)
			if sin(angle + wind) * vertex_radius < -0.35:
				mesh.append_edge_indices(id + start_point, (wrapi(id + skip, 0, polygon)) + start_point)
			if central_vertex:
				mesh.append_edge_indices(id + start_point, start_point + polygon)
			id += 1
		angle += wind
	
	if central_vertex:
		mesh.append_vertex(at_position, false)

## Creates a regular star polygon.
static func create_stellated_polygon(mesh: ArrayWireMesh4D, polygon = 5, skip = 2, vertex_radius = 1.0, x_axis = Vector4(1.0, 0.0, 0.0, 0.0), y_axis = Vector4(0.0, 1.0, 0.0, 0.0), at_position = Vector4.ZERO, central_vertex := false):
	var angle = 0.0
	var wind = TAU / float(polygon)
	var start_point = mesh.vertices.size()
	
	for i in polygon:
		var x = cos(angle) * vertex_radius
		var y = sin(angle) * vertex_radius
		mesh.append_vertex(Vector4((x * x_axis.x) + (y * y_axis.x), (x * x_axis.y) + (y * y_axis.y), (x * x_axis.z) + (y * y_axis.z), (x * x_axis.w) + (y * y_axis.w)) + at_position, false)
		mesh.append_edge_indices(i + start_point, (wrapi(i + skip, 0, polygon)) + start_point)
		if central_vertex:
			mesh.append_edge_indices(i + start_point, start_point + polygon)
		angle += wind
	
	if central_vertex:
		mesh.append_vertex(at_position, false)

## Creates 6 circles in a hypersphere wireframe arrangement.
static func create_hypersphere_wireframe(mesh: ArrayWireMesh4D, resolution = 32, radius = 1.0):
	create_polygon(resolution, radius)
	rotate_model(mesh, "YW", PI * 0.5)
	create_polygon(resolution, radius)
	rotate_model(mesh, "WX", PI * 0.5)
	create_polygon(resolution, radius)
	rotate_model(mesh, "XZ", PI * 0.5)
	create_polygon(resolution, radius)
	rotate_model(mesh, "YZ", PI * 0.5)
	create_polygon(resolution, radius)
	rotate_model(mesh, "YW", PI * 0.5)
	create_polygon(resolution, radius)

## Multiplies every vertex position by scale. Don't use on uncentered models.
static func scale_model(mesh: ArrayWireMesh4D, scale: float):
	for i in mesh.vertices.size():
		mesh.vertices[i] *= scale

## Scales the last last_points points by the scale vector. Calculates the average position of the last points.
static func scale_last(mesh: ArrayWireMesh4D, last_points: int, scale: Vector4):
	var average_position = get_average_position_of_last_points(mesh, last_points)
	for i in range(mesh.vertices.size() - last_points, mesh.vertices.size()):
		mesh.vertices[i] = ((mesh.vertices[i] - average_position) * scale) + average_position

## Scales the last last_points points by the scale vector. Does it from 0,0,0,0 and not the average position of the points.
static func scale_last_from_center(mesh: ArrayWireMesh4D, last_points: int, scale: Vector4):
	for i in range(mesh.vertices.size() - last_points, mesh.vertices.size()):
		mesh.vertices[i] *= scale

static func get_average_position_of_last_points(mesh: ArrayWireMesh4D, last_points: int) -> Vector4:
	var average_position = Vector4.ZERO
	for i in range(mesh.vertices.size() - last_points, mesh.vertices.size()):
		average_position += mesh.vertices[i]
	return average_position / last_points

## Moves all points a random amount. Use the scale to restrict it to one volume or plane. See jiggle_last().
static func jiggle_points(mesh: ArrayWireMesh4D, jiggle = 0.1, scale = Vector4.ONE):
	for i in mesh.vertices.size():
		mesh.vertices[i] += Math.random_point_in_hypersphere(jiggle) * scale

## Moves the last n points a random amount. Use the scale to restrict it to one volume or plane. See jiggle_points().
static func jiggle_last(mesh: ArrayWireMesh4D, last_points = 4, jiggle = 0.1, size = Vector4.ONE):
	for i in range(mesh.vertices.size() - last_points, mesh.vertices.size()):
		mesh.vertices[i] += Math.random_point_in_hypersphere(jiggle) * size

## Revolves the model around the origin by some plane. Use half for stuff like spheres.
static func revolve_model(mesh: ArrayWireMesh4D, plane = "XZ", resolution = 12, half = true): # good enough
	var old_vertices = mesh.vertices.duplicate()
	var old_mesh_edges = mesh.edge_indices.duplicate()
	var divisor = 2 if half else 1
	for i in resolution / divisor:
		if i != 0 and i != resolution - 1:
			for point in old_vertices.size():
				mesh.append_edge_indices(point + (old_vertices.size() * i), point + (old_vertices.size() * (i - 1)))
			for point in old_vertices.size():
				mesh.append_vertex(Math.rotate_4D(old_vertices[point], plane, (PI / ((resolution / 2) - 1)) * i), false)
			for j in range(0, old_mesh_edges.size(), 2):
				mesh.append_edge_indices(old_mesh_edges[j] + (old_vertices.size() * i), old_mesh_edges[j + 1] + (old_vertices.size() * i))
		#else:
			#for point in old_vertices.size():
				#edges.append([point + (old_vertices.size() * i), point + (old_vertices.size() * (resolution / 2))])
			#for point in old_vertices.size():
				#mesh.append_vertex(rotate_4D(old_vertices[point], plane, (PI / ((resolution / 2))) * i), false)
			#for edge in mesh_edges:
				#edges.append([edge[0] + (old_vertices.size() * i), edge[1] + (old_vertices.size() * i)])

## Rotates the last last_points points of the mesh. Use plane to specify a rotation plane, like "XZ".
static func rotate_last(mesh: ArrayWireMesh4D, last_points: int, plane: String, angle: float):
	var average_position = get_average_position_of_last_points(mesh, last_points)
	for i in range(mesh.vertices.size() - last_points, mesh.vertices.size()):
		mesh.vertices[i] = Math.rotate_4D(mesh.vertices[i] - average_position, plane, angle) + average_position

## Rotates the last last_points points of the mesh with a basis, to rotate them locally.
static func rotate_last_local(mesh: ArrayWireMesh4D, last_points: int, basis: Projection):
	var average_position = get_average_position_of_last_points(mesh, last_points)
	for i in range(mesh.vertices.size() - last_points, mesh.vertices.size()):
		mesh.vertices[i] = ((mesh.vertices[i] - average_position) * basis) + average_position

## Rotates the model on a string specified plane, like "XY". If you reverse it like "YX", the rotation will be flipped.
static func rotate_model(mesh: ArrayWireMesh4D, plane: String, angle: float):
	for i in mesh.vertices.size():
		mesh.vertices[i] = Math.rotate_4D(mesh.vertices[i], plane, angle)

## Moves every vertex of the model by motion.
static func move_model(mesh: ArrayWireMesh4D, motion: Vector4):
	for i in mesh.vertices.size():
		mesh.vertices[i] += motion

## Creates a cubic grid with each point offset vertically by noise. Optimized mesh. Resolution controls how many cubes per unit, and yes noise scale does account for it.
static func create_height_map(size = 10, height = 2, resolution = 1, noise_seed = -1) -> ArrayWireMesh4D:
	var mesh := ArrayWireMesh4D.new()
	var noise = FastNoiseLite.new()
	noise.seed = randi_range(0, 10000) if noise_seed == -1 else noise_seed
	noise.frequency = 0.05
	var id = 0
	for x in size * resolution:
		for w in size * resolution:
			for z in size * resolution:
				var real_position = Vector3((x / float(resolution)) - (size / 2), (w / float(resolution)) - (size / 2), (z / float(resolution)) - (size / 2))
				
				var point_height = noise.get_noise_3dv(real_position) * height
				
				mesh.append_vertex(Vector4(real_position.x, point_height, real_position.z, real_position.y), false)
				
				if z != (size * resolution) - 1:
					mesh.append_edge_indices(id, id + 1)
				#if z != 0:
					#mesh.append_edge_indices(id, id - 1)
				if w != (size * resolution) - 1:
					mesh.append_edge_indices(id, id + (size * resolution))
				#if w != 0:
					#mesh.append_edge_indices(id, id - (size * resolution))
				if x != (size * resolution) - 1:
					mesh.append_edge_indices(id, id + ((size * resolution) * (size * resolution)))
				#if x != 0:
					#mesh.append_edge_indices(id, id - ((size * resolution) * (size * resolution)))
				
				id += 1
	return mesh

## Creates a procedurally generated 4D tree. My own algorithm. Always makes 86 points, so its fairly low poly.
static func create_tree() -> ArrayWireMesh4D:
	var mesh: ArrayWireMesh4D = create_octahedron(0.4, 1)
	jiggle_last(mesh, 6, 0.125, Vector4(1, 0, 1, 1))
	var colored_edges := PackedColorArray()
	
	var radius = 0.4
	
	var slide = Vector4.ZERO
	
	var slide_points = []
	for i in 6:
		slide_points.append(Math.un_y_trim(Math.random_point_in_sphere(0.15 * i), 0.0))
	
	var height = 0.0
	
	var branch_final_position = Vector4.ZERO
	
	for i in 6:
		# decrease log thickness
		radius -= randf_range(0.02, 0.06)
		
		# grow tree upwards
		var grow = randf_range(0.6, 1.2)
		extrude_side_free(mesh, range(mesh.vertices.size() - 6, mesh.vertices.size()) if i != 4 else range(mesh.vertices.size() - 18, mesh.vertices.size() - 12), Vector4(0.0, -grow, 0.0, 0.0))
		
		# shift the tree horizontally
		var last = (mesh.vertices.size() - 1)
		height = mesh.vertices[last].y
		slide += slide_points[i]
		
		# reset octahedron
		mesh.vertices[last] = Vector4(0.0, height, 0.0, radius) + slide
		mesh.vertices[last - 1] = Vector4(0.0, height, radius, 0.0) + slide
		mesh.vertices[last - 2] = Vector4(radius, height, 0.0, 0.0) + slide
		mesh.vertices[last - 3] = Vector4(0.0, height, 0.0, -radius) + slide
		mesh.vertices[last - 4] = Vector4(0.0, height, -radius, 0.0) + slide
		mesh.vertices[last - 5] = Vector4(-radius, height, 0.0, 0.0) + slide
		
		# jiggle octahedron
		jiggle_last(mesh, 6, 0.125, Vector4(1, 0, 1, 1))
		if i == 3:
			var old_radius = radius
			var old_slide = slide
			
			for j in 2:
				# decrease log thickness
				radius -= randf_range(0.02, 0.06)
				
				# grow tree upwards
				var new_grow = randf_range(0.6, 1.2)
				extrude_last_free(mesh, 6, Vector4(0.0, -new_grow, 0.0, 0.0))
				
				# shift the tree horizontally
				var new_last = mesh.vertices.size() - 1
				var new_height = mesh.vertices[new_last].y
				slide += slide_points[(i + j) - 1]
				
				# reset octahedron
				var mult = 1.0
				mesh.vertices[new_last] = Vector4(0.0, new_height, 0.0, radius) - slide * mult
				mesh.vertices[new_last - 1] = Vector4(0.0, new_height, radius, 0.0) - slide * mult
				mesh.vertices[new_last - 2] = Vector4(radius, new_height, 0.0, 0.0) - slide * mult
				mesh.vertices[new_last - 3] = Vector4(0.0, new_height, 0.0, -radius) - slide * mult
				mesh.vertices[new_last - 4] = Vector4(0.0, new_height, -radius, 0.0) - slide * mult
				mesh.vertices[new_last - 5] = Vector4(-radius, new_height, 0.0, 0.0) - slide * mult
				
				# jiggle octahedron
				jiggle_last(mesh, 6, 0.125, Vector4(1, 0, 1, 1))
			
			branch_final_position = Vector4(slide.x, mesh.vertices[mesh.vertices.size() - 1].y, slide.z, slide.w)
			
			radius = old_radius
			slide = old_slide
	
	mesh.vertices = mesh.vertices
	for i in mesh.edge_indices.size() / 2:
		colored_edges.append(Color.SADDLE_BROWN)
	
	var leaves_rotation = Basis4D.from_yz(randf_range(-0.1, 0.1))
	leaves_rotation = Math.rotate_basis_global(leaves_rotation, Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), randf_range(-0.1, 0.1))
	leaves_rotation = Math.rotate_basis_global(leaves_rotation, Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1), randf_range(-0.1, 0.1))
	leaves_rotation = Basis4D.compose(leaves_rotation, Basis4D.from_zx(randf_range(-PI, PI)))
	leaves_rotation = Basis4D.compose(leaves_rotation, Basis4D.from_xw(randf_range(-PI, PI)))
	leaves_rotation = Basis4D.compose(leaves_rotation, Basis4D.from_zw(randf_range(-PI, PI)))
	
	create_tesseract(mesh, Vector4(slide.x, height, slide.z, slide.w), Vector4(randf_range(1.9, 2.1), randf_range(1.4, 1.6), randf_range(1.9, 2.1), randf_range(1.9, 2.1)) * 0.85, leaves_rotation)
	
	var second_leaves_rotation = Basis4D.from_yz(randf_range(-0.1, 0.1))
	second_leaves_rotation = Math.rotate_basis_global(leaves_rotation, Vector4(0, 1, 0, 0), Vector4(1, 0, 0, 0), randf_range(-0.1, 0.1))
	second_leaves_rotation = Math.rotate_basis_global(leaves_rotation, Vector4(0, 1, 0, 0), Vector4(0, 0, 0, 1), randf_range(-0.1, 0.1))
	second_leaves_rotation = Basis4D.compose(second_leaves_rotation, Basis4D.from_zx(randf_range(-PI, PI)))
	second_leaves_rotation = Basis4D.compose(second_leaves_rotation, Basis4D.from_xw(randf_range(-PI, PI)))
	second_leaves_rotation = Basis4D.compose(second_leaves_rotation, Basis4D.from_zw(randf_range(-PI, PI)))
	
	create_tesseract(mesh, branch_final_position * Vector4(-1, 1, -1, -1), Vector4(randf_range(1.9, 2.1), randf_range(1.4, 1.6), randf_range(1.9, 2.1), randf_range(1.9, 2.1)) * 0.85, second_leaves_rotation)
	
	for i in 64:
		colored_edges.append(Color.GREEN)
	
	var mat := WireMaterial4D.new()
	mat.albedo_source = WireMaterial4D.WIRE_COLOR_SOURCE_PER_EDGE_ONLY
	mat.albedo_color_array = colored_edges
	mesh.material = mat
	
	flip_mesh_vertically(mesh)
	
	return mesh

static func flip_mesh_vertically(mesh: ArrayWireMesh4D):
	for i in mesh.vertices.size():
		mesh.vertices[i] *= Vector4(1.0, -1.0, 1.0, 1.0)

## Creates an icosahedron. Use unused_axis to put it on a specific volume. The axis order is as follows: XYZW
static func create_icosahedron(unused_axis = 3) -> ArrayWireMesh4D:
	var mesh := ArrayWireMesh4D.new()
	var phi = (1 + sqrt(5)) / 2
	
	# Function to generate vertices with one axis unused (set to zero)
	# Vertices of an icosahedron in 3D space
	var vertices_3d = [
		Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1)
	]
	
	var vertices_4d: Array[Vector4] = []
	for vertex in vertices_3d:
		match unused_axis:
			0:
				vertices_4d.append(Vector4(0, vertex.x, vertex.y, vertex.z))
			1:
				vertices_4d.append(Vector4(vertex.x, 0, vertex.y, vertex.z))
			2:
				vertices_4d.append(Vector4(vertex.x, vertex.y, 0, vertex.z))
			3:
				vertices_4d.append(Vector4(vertex.x, vertex.y, vertex.z, 0))
	
	mesh.vertices = vertices_4d
	
	# Edge connections: list of arrays where each array represents a connection between two vertices by their indices
	mesh.edge_indices = PackedInt32Array([
		0, 1, 0, 5, 0, 7, 0, 10, 0, 11,
		1, 5, 1, 7, 1, 8, 1, 9,
		2, 3, 2, 4, 2, 6, 2, 10, 2, 11,
		3, 4, 3, 6, 3, 8, 3, 9,
		4, 5, 4, 9, 4, 11,
		5, 9, 5, 11,
		6, 7, 6, 8, 6, 10,
		7, 8, 7, 10,
		8, 9,
		10, 11,
	])
	return mesh

## Creates a tetrahedron. Use unused_axis to put it on a specific volume. The axis order is as follows: XYZW
static func create_tetrahedron(height = 1.0, unused_axis = 3) -> ArrayWireMesh4D:
	var mesh := ArrayWireMesh4D.new()
	var temp_points = []
	
	temp_points.append(Vector3(sqrt(8.0/9.0), 1.0/3.0, 0) * height)
	temp_points.append(Vector3(-sqrt(2.0/9.0), 1.0/3.0, sqrt(2.0/3.0)) * height)
	temp_points.append(Vector3(-sqrt(2.0/9.0), 1.0/3.0, -sqrt(2.0/3.0)) * height)
	temp_points.append(Vector3(0, -1, 0) * height)
	
	for a in 4:
		for b in a:
			mesh.append_edge_indices(b, a)
	
	for point in temp_points:
		match unused_axis:
			0:
				mesh.append_vertex(Vector4(0.0, point.x, point.y, point.z), false)
			1:
				mesh.append_vertex(Vector4(point.x, 0.0, point.y, point.z), false)
			2:
				mesh.append_vertex(Vector4(point.x, point.y, 0.0, point.z), false)
			3:
				mesh.append_vertex(Vector4(point.x, point.y, point.z, 0.0), false)
	return mesh

## creates a poly cube, the 3D variant of polyominoes. Input a list of vector3s. Each vector is an offset from the previous cube's position. To do branches, use non unit vectors. A cube is placed at the start so remember to have the list one less than how many cubes you want.
static func polycube(mesh: ArrayWireMesh4D, sequence: Array[Vector3], rotate_afterward = true): # mesh is not optimized, be warned
	var vector_sum = Vector4.ZERO
	create_cube(mesh)
	for step in sequence:
		move_model(mesh, Math.add_w(-step, 0.0))
		vector_sum += Math.add_w(-step, 0.0)
		create_cube(mesh)
	move_model(mesh, -vector_sum)
	
	if rotate_afterward:
		rotate_model(mesh, "WZ", PI * 0.5)
		rotate_model(mesh, "YW", PI)

## creates a poly tesseract, the 4D variant of polyominoes. See polycube() for more.
static func polytess(mesh: ArrayWireMesh4D, sequence: Array[Vector4]): # mesh is not optimized, be warned
	var vector_sum = Vector4.ZERO
	create_tesseract(mesh)
	for step in sequence:
		move_model(mesh, -step)
		vector_sum += -step
		create_tesseract(mesh)
	move_model(mesh, -vector_sum)

## Creates a tesseract. Use the matrix value to rotate it. Use the size value to scale it. Vector4.ONE results in a tess with edge lengths of one.
static func create_tesseract(mesh: ArrayWireMesh4D, tess_pos = Vector4.ZERO, size = Vector4.ONE, matrix = Projection(Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0), Vector4(0, 0, 0, 1))):
	var original_points = mesh.vertices.size()
	
	var he = size * 0.5
	
	mesh.append_vertex((Vector4(-he.x, -he.y, -he.z, -he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(+he.x, -he.y, -he.z, -he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(-he.x, +he.y, -he.z, -he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(+he.x, +he.y, -he.z, -he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(-he.x, -he.y, +he.z, -he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(+he.x, -he.y, +he.z, -he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(-he.x, +he.y, +he.z, -he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(+he.x, +he.y, +he.z, -he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(-he.x, -he.y, -he.z, +he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(+he.x, -he.y, -he.z, +he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(-he.x, +he.y, -he.z, +he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(+he.x, +he.y, -he.z, +he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(-he.x, -he.y, +he.z, +he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(+he.x, -he.y, +he.z, +he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(-he.x, +he.y, +he.z, +he.w) * matrix) + tess_pos)
	mesh.append_vertex((Vector4(+he.x, +he.y, +he.z, +he.w) * matrix) + tess_pos)
	
	mesh.append_edge_indices(0 + original_points, 1 + original_points)
	mesh.append_edge_indices(0 + original_points, 2 + original_points)
	mesh.append_edge_indices(0 + original_points, 4 + original_points)
	mesh.append_edge_indices(0 + original_points, 8 + original_points)
	
	mesh.append_edge_indices(1 + original_points, 3 + original_points)
	mesh.append_edge_indices(1 + original_points, 5 + original_points)
	mesh.append_edge_indices(1 + original_points, 9 + original_points)
	
	mesh.append_edge_indices(2 + original_points, 3 + original_points)
	mesh.append_edge_indices(2 + original_points, 6 + original_points)
	mesh.append_edge_indices(2 + original_points, 10 + original_points)
	
	mesh.append_edge_indices(3 + original_points, 7 + original_points)
	mesh.append_edge_indices(3 + original_points, 11 + original_points)
	
	mesh.append_edge_indices(4 + original_points, 5 + original_points)
	mesh.append_edge_indices(4 + original_points, 6 + original_points)
	mesh.append_edge_indices(4 + original_points, 12 + original_points)
	
	mesh.append_edge_indices(5 + original_points, 7 + original_points)
	mesh.append_edge_indices(5 + original_points, 13 + original_points)
	
	mesh.append_edge_indices(6 + original_points, 7 + original_points)
	mesh.append_edge_indices(6 + original_points, 14 + original_points)
	
	mesh.append_edge_indices(7 + original_points, 15 + original_points)
	
	mesh.append_edge_indices(8 + original_points, 9 + original_points)
	mesh.append_edge_indices(8 + original_points, 10 + original_points)
	mesh.append_edge_indices(8 + original_points, 12 + original_points)
	
	mesh.append_edge_indices(9 + original_points, 11 + original_points)
	mesh.append_edge_indices(9 + original_points, 13 + original_points)
	
	mesh.append_edge_indices(10 + original_points, 11 + original_points)
	mesh.append_edge_indices(10 + original_points, 14 + original_points)
	
	mesh.append_edge_indices(11 + original_points, 15 + original_points)
	
	mesh.append_edge_indices(12 + original_points, 13 + original_points)
	mesh.append_edge_indices(12 + original_points, 14 + original_points)
	
	mesh.append_edge_indices(13 + original_points, 15 + original_points)
	
	mesh.append_edge_indices(14 + original_points, 15 + original_points)

## Creates a cube. Use unused_axis to put it on a specific volume. The axis order is as follows: XYZW.
static func create_cube(mesh: ArrayWireMesh4D, unused_axis = 3, at_position = Vector4.ZERO, size = Vector3.ONE):
	var points_3d = []
	var original_points = mesh.vertices.size()
	
	for i in 8:
		var i_wrapped_to_4 = i if i < 4 else i - 4
		var y = -1.0 if i_wrapped_to_4 < 2 else 1.0
		var z = -1.0 if i % 2 == 0 else 1.0
		points_3d.append(Vector3(-1.0 if i < 4 else 1.0, y, z) * size * 0.5)
	
	for point in points_3d:
		match unused_axis:
			0:
				mesh.append_vertex(Vector4(0.0, point.x, point.y, point.z) + at_position, false)
			1:
				mesh.append_vertex(Vector4(point.x, 0.0, point.y, point.z) + at_position, false)
			2:
				mesh.append_vertex(Vector4(point.x, point.y, 0.0, point.z) + at_position, false)
			3:
				mesh.append_vertex(Vector4(point.x, point.y, point.z, 0.0) + at_position, false)
	
	for i in 7:
		if !check_edge(mesh, [(i ^ 0b001) + original_points, i + original_points]):
			mesh.append_edge_indices(i + original_points, (i ^ 0b001) + original_points)
		if !check_edge(mesh, [(i ^ 0b010) + original_points, i + original_points]):
			mesh.append_edge_indices(i + original_points, (i ^ 0b010) + original_points)
		if !check_edge(mesh, [(i ^ 0b100) + original_points, i + original_points]):
			mesh.append_edge_indices(i + original_points, (i ^ 0b100) + original_points)

## Extrudes the shape into the axis. Don't use on 4D shapes.
static func extrude(mesh: ArrayWireMesh4D, height = 3.0, axis = 3):
	var second_shape = mesh.vertices.duplicate()
	var shape_size = second_shape.size()
	for i in shape_size:
		second_shape[i] += Vector4(float(axis == 0), float(axis == 1), float(axis == 2), float(axis == 3)) * height
	
	mesh.append_vertices(second_shape, false)
	
	#var second_shape_edges = mesh.edge_indices.duplicate()
	#for i in range(0, second_shape_edges.size(), 2):
	#	second_shape_edges[i] += shape_size
	#	second_shape_edges[i + 1] += shape_size
	#mesh.append_edge_indices_array(second_shape_edges)
	var edge_indices = mesh.edge_indices.duplicate()
	for i in range(0, edge_indices.size(), 2):
		mesh.append_edge_indices(edge_indices[i] + shape_size, edge_indices[i + 1] + shape_size)
	
	for i in shape_size:
		mesh.append_edge_indices(i, i + shape_size)

## Creates a regular pentachoron with a specified edge length. Generates tetrahedron down, like a pyramid.
static func create_5_cell(edge_length = 1.0) -> ArrayWireMesh4D:
	var mesh := ArrayWireMesh4D.new()
	
	var bottom = 1.0 / sqrt(5.0)
	var top = -4.0 / sqrt(5.0)
	var default_edge_length = 2.82842707633972
	var edge_reciprocal = 1.0 / default_edge_length
	
	mesh.append_vertex(Vector4(1, bottom, 1, 1) * edge_reciprocal * edge_length, false)
	mesh.append_vertex(Vector4(1, bottom, -1, -1) * edge_reciprocal * edge_length, false)
	mesh.append_vertex(Vector4(-1, bottom, 1, -1) * edge_reciprocal * edge_length, false)
	mesh.append_vertex(Vector4(-1, bottom, -1, 1) * edge_reciprocal * edge_length, false)
	mesh.append_vertex(Vector4(0, top, 0, 0) * edge_reciprocal * edge_length, false)
	
	for a in 5:
		for b in a:
			mesh.append_edge_indices(b, a)
	return mesh

## Returns true if edge exists. Useful for checking if [b, a] exists before making an edge [a, b].
static func check_edge(mesh: ArrayWireMesh4D, edge: Array[int]) -> bool:
	return mesh.has_edge_indices(edge[0], edge[1])

## Creates a dodecahedron. Use unused_axis to put it on a specific volume. The axis order is as follows: XYZW
static func create_dodecahedron(unused_axis = 3, radius = 0.5) -> ArrayWireMesh4D:
	# The golden ratio
	var phi = (1 + sqrt(5)) / 2
	
	# Vertices of a dodecahedron
	var vertices = [
		Vector3(1, 1, 1),
		Vector3(1, 1, -1),
		Vector3(1, -1, 1),
		Vector3(1, -1, -1),
		Vector3(-1, 1, 1),
		Vector3(-1, 1, -1),
		Vector3(-1, -1, 1),
		Vector3(-1, -1, -1),
		Vector3(0, 1 / phi, phi),
		Vector3(0, 1 / phi, -phi),
		Vector3(0, -1 / phi, phi),
		Vector3(0, -1 / phi, -phi),
		Vector3(1 / phi, phi, 0),
		Vector3(1 / phi, -phi, 0),
		Vector3(-1 / phi, phi, 0),
		Vector3(-1 / phi, -phi, 0),
		Vector3(phi, 0, 1 / phi),
		Vector3(phi, 0, -1 / phi),
		Vector3(-phi, 0, 1 / phi),
		Vector3(-phi, 0, -1 / phi)
	]
	
	var vertices_4d: Array[Vector4] = []
	for vertex in vertices:
		match unused_axis:
			0:
				vertices_4d.append(Vector4(0, vertex.x, vertex.y, vertex.z) * radius * (1.0 / phi))
			1:
				vertices_4d.append(Vector4(vertex.x, 0, vertex.y, vertex.z) * radius * (1.0 / phi))
			2:
				vertices_4d.append(Vector4(vertex.x, vertex.y, 0, vertex.z) * radius * (1.0 / phi))
			3:
				vertices_4d.append(Vector4(vertex.x, vertex.y, vertex.z, 0) * radius * (1.0 / phi))
	
	# Edge connections: list of arrays where each array represents a connection between two vertices by their indices
	var edge_table = [
		0, 8, 0, 12, 0, 16,
		1, 9, 1, 12, 1, 17,
		2, 10, 2, 13, 2, 16,
		3, 11, 3, 13, 3, 17,
		4, 8, 4, 14, 4, 18,
		5, 9, 5, 14, 5, 19,
		6, 10, 6, 15, 6, 18,
		7, 11, 7, 15, 7, 19,
		8, 10, 9, 11,
		12, 14, 13, 15,
		16, 17, 18, 19
	]
	var mesh := ArrayWireMesh4D.new()
	mesh.edge_indices = edge_table
	mesh.vertices = vertices_4d
	return mesh


## Creates a 4-orthoplex (16-cell) with the specified vertex radius.
static func create_16_cell(vertex_radius = 0.5) -> ArrayWireMesh4D:
	var mesh := ArrayWireMesh4D.new()
	for d in [-1, 1]:
		for axis in 4:
			var point = Vector4.ZERO
			point.x = vertex_radius * d if axis == 0 else 0.0
			point.y = vertex_radius * d if axis == 1 else 0.0
			point.z = vertex_radius * d if axis == 2 else 0.0
			point.w = vertex_radius * d if axis == 3 else 0.0
			
			mesh.append_vertex(point, false)
	
	for i in 8:
		for j in 8:
			if i != j and j - 4 != i and i - 4 != j and i < j:
				if !mesh.has_edge_indices(i, j):
					mesh.append_edge_indices(i, j)
	return mesh


## Creates a crappy UV sphere. Unlike most UV sphere algorithms, quality_1 and quality_2 should be equal for square faces. On the XYZ volume.
static func create_sphere(mesh: ArrayWireMesh4D, radius = 0.5, quality_1 = 12, quality_2 = 12):
	create_polygon(mesh, quality_1, radius)
	revolve_model(mesh, "XZ", quality_2)


## Creates an octahedron. Use unused_axis to put it on a specific volume. The axis order is as follows: XYZW
static func create_octahedron(vertex_radius = 0.5, unused_axis = 2) -> ArrayWireMesh4D:
	var mesh := ArrayWireMesh4D.new()
	for d in [-1, 1]:
		for axis in 3:
			var point = Vector3.ZERO
			point.x = vertex_radius * d if axis == 0 else 0.0
			point.y = vertex_radius * d if axis == 1 else 0.0
			point.z = vertex_radius * d if axis == 2 else 0.0
			
			var point_4d = Vector4.ZERO
			match unused_axis:
				0:
					point_4d = Vector4(0, point.x, point.y, point.z)
				1:
					point_4d = Vector4(point.x, 0, point.y, point.z)
				2:
					point_4d = Vector4(point.x, point.y, 0, point.z)
				3:
					point_4d = Vector4(point.x, point.y, point.z, 0)
			
			mesh.append_vertex(point_4d, false)
	
	for i in 6:
		for j in 6:
			if i != j and j - 3 != i and i - 3 != j:
				if not mesh.has_edge_indices(i, j): #if !edges.has([i, j]) and !edges.has([j, i]):
					#edges.append([i, j])
					# TODO is the mini/maxi stuff needed?
					mesh.append_edge_indices(mini(i, j), maxi(i, j))
	return mesh


## Creates a 24 cell. 4D rhombic dodecahedron.
static func create_24_cell(vertex_radius = 0.5) -> ArrayWireMesh4D:
	var mesh := ArrayWireMesh4D.new()
	# I recommend the rotation (XZ: 45 degrees, YW: 45 degrees) as it will show the octahedral cell. Very pretty.
	
	# tesseract points
	for i in 16:
		var i_wrapped_to_8 = i if i < 8 else i - 8
		var y = -0.5 if (i_wrapped_to_8) < 4 else 0.5
		var i_wrapped_to_4 = i_wrapped_to_8 if i_wrapped_to_8 < 4 else i_wrapped_to_8 - 4
		var z = -0.5 if (i_wrapped_to_4) < 2 else 0.5
		var w = -0.5 if i % 2 == 0 else 0.5
		mesh.append_vertex(Vector4(-0.5 if i < 8 else 0.5, y, z, w) * vertex_radius, false)
	
	# tesseract edges
	for i in 16:
		mesh.append_edge_indices(i, i ^ 0b0001)
		mesh.append_edge_indices(i, i ^ 0b0010)
		mesh.append_edge_indices(i, i ^ 0b0100)
		mesh.append_edge_indices(i, i ^ 0b1000)
	
	# pyramid points
	for i in 8:
		match int(floor(float(i) / 2.0)):
			0:
				mesh.append_vertex(Vector4(1, 0, 0, 0) * (-1 if i % 2 == 0 else 1) * vertex_radius, false)
			1:
				mesh.append_vertex(Vector4(0, 1, 0, 0) * (-1 if i % 2 == 0 else 1) * vertex_radius, false)
			2:
				mesh.append_vertex(Vector4(0, 0, 1, 0) * (-1 if i % 2 == 0 else 1) * vertex_radius, false)
			3:
				mesh.append_vertex(Vector4(0, 0, 0, 1) * (-1 if i % 2 == 0 else 1) * vertex_radius, false)
	
	for i in 8:
		match i:
			0:
				for j in 8:
					mesh.append_edge_indices(i+16, j)
			1:
				for j in 8:
					mesh.append_edge_indices(i+16, j+8)
			2:
				for j in 4:
					mesh.append_edge_indices(i+16, j)
				for j in 4:
					mesh.append_edge_indices(i+16, j + 8)
			3:
				for j in 4:
					mesh.append_edge_indices(i+16, j + 4)
				for j in 4:
					mesh.append_edge_indices(i+16, j + 12)
			4:
				for j in 2:
					mesh.append_edge_indices(i+16, j)
				for j in 2:
					mesh.append_edge_indices(i+16, j + 4)
				for j in 2:
					mesh.append_edge_indices(i+16, j + 8)
				for j in 2:
					mesh.append_edge_indices(i+16, j + 12)
			5:
				for j in 2:
					mesh.append_edge_indices(i+16, j + 2)
				for j in 2:
					mesh.append_edge_indices(i+16, j + 6)
				for j in 2:
					mesh.append_edge_indices(i+16, j + 10)
				for j in 2:
					mesh.append_edge_indices(i+16, j + 14)
			6:
				for j in 8:
					mesh.append_edge_indices(i+16, j * 2)
			7:
				for j in 8:
					mesh.append_edge_indices(i+16, (j * 2) + 1)
	return mesh

## Forward is negative Z
static func project_model(model: ArrayWireMesh4D, from: Vector4, view_direction = Projection.IDENTITY, focal_length = 1.0, render_material = false) -> ArrayWireMesh4D:
	var image := ArrayWireMesh4D.new()
	
	for vert in model.vertices:
		var transformed_vert = (vert - from) * Basis4D.inverse(view_direction)
		
		image.append_vertex((transformed_vert / (transformed_vert.z / focal_length)) * Vector4(1, 1, 0, 1), false)
	
	image.edge_indices = model.edge_indices.duplicate()
	
	if render_material:
		image.material = model.material.duplicate()
	
	return image
