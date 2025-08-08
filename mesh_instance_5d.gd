extends Node4D

@onready var visual := $Visual

## Position along the V axis. This is global, so the V axis always stays perpendicular to XYZW.
@export var v_pos := 0.0

## Euler rotation into the nV planes. Measured in radians ofc
@export var euler_5D := Vector4.ZERO

@export var mesh: Mesh5D

func rotate_point(point_xyzw: Vector4, point_v: float, plane: int) -> Array:
	var axis := point_xyzw[plane]
	point_xyzw[plane] = (axis * cos(euler_5D[plane])) - (point_v * sin(euler_5D[plane]))
	point_v = (axis * sin(euler_5D[plane])) + (point_v * cos(euler_5D[plane]))
	
	return [point_xyzw, point_v]

func rotate_triangle(triangle: Array, plane: int):
	var rotated_point_1 = rotate_point(triangle[0], triangle[1], plane)
	var rotated_point_2 = rotate_point(triangle[2], triangle[3], plane)
	var rotated_point_3 = rotate_point(triangle[4], triangle[5], plane)
	
	return [rotated_point_1[0], rotated_point_1[1], rotated_point_2[0], rotated_point_2[1], rotated_point_3[0], rotated_point_3[1]]

func slice():
	var sliced_mesh := ArrayWireMesh4D.new()
	
	for point_1_index in range(0, mesh.triangles.size(), 3):
		var point_2_index := point_1_index + 1
		var point_3_index := point_2_index + 1
		
		var transformed_triangle = [
			mesh.vertices_xyzw[mesh.triangles[point_1_index]],
			mesh.vertices_v[mesh.triangles[point_1_index]],
			mesh.vertices_xyzw[mesh.triangles[point_2_index]],
			mesh.vertices_v[mesh.triangles[point_2_index]],
			mesh.vertices_xyzw[mesh.triangles[point_3_index]],
			mesh.vertices_v[mesh.triangles[point_3_index]]
		]
		
		transformed_triangle = rotate_triangle(transformed_triangle, 0) # XV
		transformed_triangle = rotate_triangle(transformed_triangle, 1) # YV
		transformed_triangle = rotate_triangle(transformed_triangle, 2) # ZV
		transformed_triangle = rotate_triangle(transformed_triangle, 3) # WV
		
		transformed_triangle[1] += v_pos
		transformed_triangle[3] += v_pos
		transformed_triangle[5] += v_pos
		
		# Check if triangle intersects hypervolume
		if absf(signf(transformed_triangle[1]) + signf(transformed_triangle[3]) + signf(transformed_triangle[5])) < 3:
			var intersection_points: Array[Vector4]
			
			if signf(transformed_triangle[1]) != signf(transformed_triangle[3]):
				intersection_points.append(calculate_intersection(transformed_triangle[0], transformed_triangle[1], transformed_triangle[2], transformed_triangle[3]))
			if signf(transformed_triangle[1]) != signf(transformed_triangle[5]):
				intersection_points.append(calculate_intersection(transformed_triangle[0], transformed_triangle[1], transformed_triangle[4], transformed_triangle[5]))
			if signf(transformed_triangle[5]) != signf(transformed_triangle[3]):
				intersection_points.append(calculate_intersection(transformed_triangle[4], transformed_triangle[5], transformed_triangle[2], transformed_triangle[3]))
			
			if intersection_points.size() == 2:
				sliced_mesh.append_edge_points(intersection_points[0], intersection_points[1])
	
	sliced_mesh.material = mesh.material
	visual.mesh = sliced_mesh

func calculate_intersection(point_1_xyzw: Vector4, point_1_v: float, point_2_xyzw: Vector4, point_2_v: float):
	var inbetween_fraction := inverse_lerp(point_1_v, point_2_v, 0.0)
	return lerp(point_1_xyzw, point_2_xyzw, inbetween_fraction)

func _process(delta):
	slice()
