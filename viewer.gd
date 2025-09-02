extends Node4D

var mouse_sensitivity := 0.004 * (2560.0 / float(ProjectSettings.get_setting("display/window/size/viewport_width")))

@onready var camera = $Camera
@onready var visual = $Visual
@onready var visual_5D = $Visual5D
@onready var axes = $Axes
@onready var ui = $UI
@onready var filename_label = $Filename

var revealed := 0.0

var zoom := 1.0

var line_thickness := 8.0

var camera_fade_start := 3.5
var camera_fade_end := 5.0
var camera_w_fade_distance := 1.0
var camera_w_fade_slope := 0.0
var camera_w_fade_distance_focus := 0.25
var camera_w_fade_slope_focus := 0.0

var xy_angle := 0.0
var zw_angle := 0.0
var yv_angle := 0.0

var xy_speed := 0.0
var zw_speed := 0.0
var yv_speed := 0.0

var selected := ""

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.projection_type = Camera4D.PROJECTION4D_PERSPECTIVE_4D

func reset_view(fully = true):
	if visual.visible:
		if visual.position.w == 0.0 or fully:
			basis = Projection.IDENTITY
		visual.position.w = 0.0
	else:
		if visual_5D.v_pos == 0.001 or fully:
			basis = Projection.IDENTITY
			visual_5D.euler_5D = Vector4.ZERO
		visual_5D.v_pos = 0.001

func _process(delta):
	if Input.is_action_just_pressed("reveal"):
		filename_label.text = selected
		revealed = 3.0
	
	revealed -= delta
	filename_label.modulate.a = clampf(revealed, 0.0, 1.0)
	
	camera.w_fade_distance = lerpf(camera.w_fade_distance, camera_w_fade_distance_focus if Input.is_action_pressed("focus") else camera_w_fade_distance, 1.0 - pow(2.0, -delta / 0.1))
	camera.w_fade_slope = lerpf(camera.w_fade_slope, camera_w_fade_slope_focus if Input.is_action_pressed("focus") else camera_w_fade_slope, 1.0 - pow(2.0, -delta / 0.1))
	
	if Input.is_action_pressed("ana"):
		if visual_5D.visible:
			visual_5D.v_pos -= (delta / zoom) / 2.0
		else:
			visual.position.w -= (delta / zoom) / 2.0
	if Input.is_action_pressed("kata"):
		if visual_5D.visible:
			visual_5D.v_pos += (delta / zoom) / 2.0
		else:
			visual.position.w += (delta / zoom) / 2.0
	if Input.is_action_just_pressed("reset view"):
		reset_view(false)
	
	if visual_5D.visible:
		var angular_speed := 1.0
		if Input.is_action_pressed("xv"):
			visual_5D.euler_5D.x += angular_speed * delta
		if Input.is_action_pressed("vx"):
			visual_5D.euler_5D.x -= angular_speed * delta
		if Input.is_action_pressed("yv"):
			visual_5D.euler_5D.y += angular_speed * delta
		if Input.is_action_pressed("vy"):
			visual_5D.euler_5D.y -= angular_speed * delta
		if Input.is_action_pressed("zv"):
			visual_5D.euler_5D.z += angular_speed * delta
		if Input.is_action_pressed("vz"):
			visual_5D.euler_5D.z -= angular_speed * delta
		if Input.is_action_pressed("wv"):
			visual_5D.euler_5D.w += angular_speed * delta
		if Input.is_action_pressed("vw"):
			visual_5D.euler_5D.w -= angular_speed * delta
	
	axes.global_basis = Projection.IDENTITY
	
	xy_angle = wrapf(xy_angle + (xy_speed * delta), 0.0, TAU)
	zw_angle = wrapf(zw_angle + (zw_speed * delta), 0.0, TAU)
	yv_angle = wrapf(yv_angle + (yv_speed * delta), 0.0, TAU)
	
	if visual.visible:
		if xy_speed != 0.0 or zw_speed != 0.0:
			visual.global_basis = Basis4D.from_scale(Vector4.ONE * zoom)
			visual.global_basis *= Basis4D.from_xy(xy_angle)
			visual.global_basis *= Basis4D.from_zw(zw_angle)
	else:
		if xy_speed != 0.0 or zw_speed != 0.0 or yv_speed != 0.0:
			visual_5D.global_basis = Basis4D.from_scale(Vector4.ONE * zoom)
			visual_5D.global_basis *= Basis4D.from_xy(xy_angle)
			visual_5D.global_basis *= Basis4D.from_zw(zw_angle)
			visual_5D.euler_5D.y = yv_angle

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			ui.visible = !ui.visible
			if ui.visible:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_SHIFT):
				line_thickness *= 8.0 / 7.0
			elif Input.is_key_pressed(KEY_CTRL):
				camera.focal_length_4d *= 8.0 / 7.0
			else:
				zoom *= 7.0 / 6.0
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_SHIFT):
				line_thickness *= 7.0 / 8.0
			elif Input.is_key_pressed(KEY_CTRL):
				camera.focal_length_4d *= 7.0 / 8.0
			else:
				zoom *= 6.0 / 7.0
		visual.material_override.line_thickness = line_thickness
		if visual_5D.mesh:
			if visual_5D.mesh.material:
				visual_5D.mesh.material.line_thickness = line_thickness
			else:
				visual_5D.mesh.material = WireMaterial4D.new()
				visual_5D.mesh.material.line_thickness = line_thickness
	
	if event is InputEventMouseMotion and !ui.visible:
		if Input.is_action_pressed("4d look"):
			basis *= Basis4D.from_xw(event.relative.x * -mouse_sensitivity)
			basis *= Basis4D.from_wy(event.relative.y * mouse_sensitivity)
		elif Input.is_action_pressed("roll look"):
			basis *= Basis4D.from_xy(event.relative.x * mouse_sensitivity)
			basis *= Basis4D.from_zw(event.relative.y * mouse_sensitivity)
		else:
			basis *= Basis4D.from_zx(event.relative.x * -mouse_sensitivity)
			basis *= Basis4D.from_yz(event.relative.y * -mouse_sensitivity)
	
	if visual.visible:
		visual.global_basis = Basis4D.from_scale(Vector4.ONE * zoom)
	else:
		visual_5D.global_basis = Basis4D.from_scale(Vector4.ONE * zoom)

func _camera_fade_start_changed(value):
	camera_fade_start = value
	update_camera()

func _camera_fade_end_changed(value):
	camera_fade_end = value
	update_camera()

func _camera_w_fade_distance_changed(value):
	camera_w_fade_distance = value
	update_camera()

func _camera_w_fade_slope_changed(value):
	camera_w_fade_slope = value
	update_camera()

func _camera_w_fade_distance_focus_changed(value):
	camera_w_fade_distance_focus = value
	update_camera()

func _camera_w_fade_slope_focus_changed(value):
	camera_w_fade_slope_focus = value
	update_camera()

func update_camera():
	camera.depth_fade_start = camera_fade_start
	if camera.depth_fade_mode == 3:
		camera.clip_far = camera_fade_end
	else:
		camera.clip_far = 256.0

func _depth_fade_toggled(toggled_on):
	camera.depth_fade_mode = 3 if toggled_on else 0
	update_camera()

func _on_load_pressed():
	var screen_size := Vector2i(2560, 1440)
	var size := screen_size / 2
	$FileDialog.popup(Rect2i((screen_size - size) / 2, size))

func _on_file_dialog_file_selected(path: String):
	load_polytope(path)

func load_polytope(path: String):
	if path.ends_with("tres"):
		var mesh = ResourceLoader.load(path)
		
		if mesh is ArrayWireMesh4D or mesh is ArrayTetraMesh4D:
			visual.mesh = mesh
			visual.visible = true
			visual_5D.visible = false
		elif mesh is Mesh5D:
			visual.visible = false
			visual_5D.visible = true
			visual_5D.mesh = mesh
	else:
		var file := FileAccess.open(path, FileAccess.READ)
		var dimensions := 0
		for i in 6:
			var line := file.get_line()
			if line == "4OFF":
				dimensions = 4
				break
			if line == "3OFF":
				dimensions = 3
				break
			if line == "5OFF":
				dimensions = 5
				break
		
		if dimensions < 5:
			var off_doc: OFFDocument4D = OFFDocument4D.load_from_file(path)
			var wire_mesh: ArrayWireMesh4D = off_doc.generate_wire_mesh_4d()
			
			visual.mesh = wire_mesh
			visual.visible = true
			visual_5D.visible = false
		elif dimensions == 5:
			visual_5D.visible = true
			visual.visible = false
			
			visual_5D.mesh = import_5D_off(path)
	
	reset_view()

func _on_subdivide():
	if visual.mesh and visual.visible:
		var mesh = visual.mesh.duplicate()
		Model.subdivide_edges(mesh)
		visual.mesh = mesh

func import_5D_off(file_path: String) -> Mesh5D:
	var mesh := Mesh5D.new()
	
	var off := FileAccess.open(file_path, FileAccess.READ)
	
	var text := off.get_as_text()
	
	var lines := text.split("\n")
	
	var vert_count := 0
	var face_count := 0
	
	for i in 6:
		if lines[i].contains("Edges"):
			var numbers := lines[i + 1].split(" ")
			vert_count = int(numbers[0])
			face_count = int(numbers[1])
			break
	
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
				if line.to_lower().contains("cells"):
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
		
		if line.to_lower().contains("vertices") and !line.to_lower().contains("faces"):
			mode = 1
		elif line.to_lower().contains("faces") and !line.to_lower().contains("vertices"):
			mode = 2
	
	return mesh

func _on_axes_toggled(toggled_on):
	axes.visible = toggled_on

func _yv_speed(value):
	yv_speed = value

func _zw_speed(value):
	zw_speed = value

func _xy_speed(value):
	xy_speed = value

func _on_random_model_loaded():
	var screen_size := Vector2i(2560, 1440)
	var size := screen_size / 2
	$FileDialog2.popup(Rect2i((screen_size - size) / 2, size))

func _on_folder_selected(dir: String):
	var folder := DirAccess.open(dir)
	var files = folder.get_files()
	var accepted_files = PackedStringArray()
	
	for file_path in files:
		if file_path.ends_with(".off") or file_path.ends_with(".tres"):
			accepted_files.append(file_path)
	
	if !accepted_files.is_empty():
		selected = accepted_files[randi() % accepted_files.size()]
		load_polytope(dir + "/" + selected)
