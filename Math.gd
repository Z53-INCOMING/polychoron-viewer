@icon("res://Icons/Math.png")
## Vector related math utilities.
class_name Math extends Object

# ChatGPT4o made this code :(
## Rotates a vector inside a plane defined by two normalized vectors.
static func rotate_vector_in_plane(a: Vector4, u: Vector4, v: Vector4, theta: float) -> Vector4:
	# Ensure u and v are orthonormal
	u = u.normalized()
	v = (v - v.dot(u) * u).normalized() # Gram-Schmidt process
	
	# Rotation matrix in the u-v plane
	var cos_theta = cos(theta)
	var sin_theta = sin(theta)
	
	# Rotation matrix elements
	var r_uu = u * cos_theta + v * sin_theta
	var r_uv = u * -sin_theta + v * cos_theta
	
	# Project a onto the u and v vectors
	var proj_u = a.dot(u)
	var proj_v = a.dot(v)
	
	# Rotate the projections
	var rotated_proj = r_uu * proj_u + r_uv * proj_v
	
	# Project the rotated vector back to 4D space
	var result = rotated_proj + (a - (proj_u * u + proj_v * v))
	return result

## Rotates a basis in global space.
static func rotate_basis_global(basis: Projection, plane_vec_1: Vector4, plane_vec_2: Vector4, angle: float) -> Projection:
	var new_basis = basis
	for i in 4:
		new_basis[i] = rotate_vector_in_plane(new_basis[i], plane_vec_1, plane_vec_2, angle)
	return new_basis

## Removes the W component from a vector.
static func trim(vec4: Vector4) -> Vector3:
	return Vector3(vec4.x, vec4.y, vec4.z)

## Adds the W component to a vector.
static func add_w(vec3: Vector3, w: float) -> Vector4:
	return Vector4(vec3.x, vec3.y, vec3.z, w)

## Removes the Y component from a vector.
static func y_trim(vec4: Vector4) -> Vector3:
	return Vector3(vec4.x, vec4.z, vec4.w)

## Adds the Y component to a vector.
static func un_y_trim(vec3: Vector3, w: float) -> Vector4:
	return Vector4(vec3.x, w, vec3.y, vec3.z)

## Removes the X component from a vector.
static func x_trim(vec4: Vector4) -> Vector3:
	return Vector3(vec4.y, vec4.z, vec4.w)

## Adds the Y component to a vector.
static func un_x_trim(vec3: Vector3, w: float) -> Vector4:
	return Vector4(w, vec3.x, vec3.y, vec3.z)

## Gets a random uniform point inside a hypersphere.
static func random_point_in_hypersphere(radius = 1.0) -> Vector4:
	var random_point = Vector4(randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius))
	while true:
		if random_point.length_squared() <= radius * radius:
			break
		
		random_point = Vector4(randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius))
	return random_point

## Gets a random uniform point inside a sphere.
static func random_point_in_sphere(radius = 1.0) -> Vector3:
	var random_point = Vector3(randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius))
	while true:
		if random_point.length_squared() <= radius * radius:
			break
		
		random_point = Vector3(randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius))
	return random_point

## Gets a random uniform point inside a sphere, that's also not inside a smaller sphere. I think it'll crash if inner_radius is bigger than radius, so don't do that.
static func random_point_in_hollow_sphere(radius = 1.0, inner_radius = 0.5) -> Vector3:
	var random_point = Vector3(randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius))
	while true:
		if random_point.length_squared() <= radius * radius:
			var length = random_point.length()
			random_point *= remap(length, 0.0, radius, inner_radius, radius) / length
			break
		
		random_point = Vector3(randf_range(-radius, radius), randf_range(-radius, radius), randf_range(-radius, radius))
	return random_point

## Gets a random uniform point inside a circle.
static func random_point_in_circle(radius = 1.0) -> Vector2:
	var random_point = Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
	while true:
		if random_point.length_squared() <= radius * radius:
			break
		
		random_point = Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
	return random_point

## Gets a random uniform point inside a duocylinder. I don't think this has any actual use. I made the function for fun.
static func random_point_in_duocylinder(radius_a = 1.0, radius_b = 1.0) -> Vector4:
	var random_point_xy := random_point_in_circle(radius_a)
	var random_point_zw := random_point_in_circle(radius_b)
	
	var random_point = Vector4(random_point_xy.x, random_point_xy.y, random_point_zw.x, random_point_zw.y)
	
	return random_point

## Rotates a point inside a plane defined by a string, like "XY" or "ZW".
static func rotate_4D(point: Vector4, plane: String, angle: float):
	var vectorized_plane = plane_string_to_vectors(plane)
	return rotate_vector_in_plane(point, vectorized_plane[0], vectorized_plane[1], angle)

## Rotates a point six times, once for each plane.
static func full_rotation(point: Vector4, rotation_3: Vector3, rotation_4: Vector3):
	return rotate_4D(rotate_4D(rotate_4D(rotate_4D(rotate_4D(rotate_4D(point, "XZ", rotation_3.y), "YZ", rotation_3.x), "XY", rotation_3.z), "XW", rotation_4.x), "YW", rotation_4.y), "WZ", rotation_4.z)

## Converts a plane string like "YZ" to a vector array string, like "[Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0)]".
static func plane_string_to_vectors(plane: String) -> Array[Vector4]:
	var first_vec = Vector4(1, 0, 0, 0) if plane[0] == "X" else (Vector4(0, 1, 0, 0) if plane[0] == "Y" else (Vector4(0, 0, 1, 0) if plane[0] == "Z" else (Vector4(0, 0, 0, 1) if plane[0] == "W" else Vector4.ZERO)))
	var second_vec = Vector4(1, 0, 0, 0) if plane[1] == "X" else (Vector4(0, 1, 0, 0) if plane[1] == "Y" else (Vector4(0, 0, 1, 0) if plane[1] == "Z" else (Vector4(0, 0, 0, 1) if plane[1] == "W" else Vector4.ZERO)))
	
	return [first_vec, second_vec]
