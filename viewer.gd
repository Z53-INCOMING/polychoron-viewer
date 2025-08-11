extends Node4D

var mouse_sensitivity := 0.004 * (2560.0 / float(ProjectSettings.get_setting("display/window/size/viewport_width")))

@onready var camera = $Camera
@onready var visual = $Visual
@onready var ui = $UI

var zoom := 1.0

var line_thickness := 8.0

var camera_fade_start := 3.5
var camera_fade_end := 5.0
var camera_w_fade_distance := 1.0
var camera_w_fade_slope := 0.0
var camera_w_fade_distance_focus := 0.25
var camera_w_fade_slope_focus := 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.projection_type = Camera4D.PROJECTION4D_PERSPECTIVE_4D

func _process(delta):
	camera.w_fade_distance = lerpf(camera.w_fade_distance, camera_w_fade_distance_focus if Input.is_action_pressed("focus") else camera_w_fade_distance, 1.0 - pow(2.0, -delta / 0.1))
	camera.w_fade_slope = lerpf(camera.w_fade_slope, camera_w_fade_slope_focus if Input.is_action_pressed("focus") else camera_w_fade_slope, 1.0 - pow(2.0, -delta / 0.1))

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
	
	visual.global_basis = Basis4D.from_scale(Vector4.ONE * zoom)

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
	camera_w_fade_slope_focus = value
	update_camera()

func _camera_w_fade_slope_focus_changed(value):
	camera_w_fade_slope_focus = value
	update_camera()

func update_camera():
	camera.depth_fade_start = camera_fade_start
	if camera.depth_fade:
		camera.clip_far = camera_fade_end
	else:
		camera.clip_far = 256.0

func _depth_fade_toggled(toggled_on):
	camera.depth_fade = toggled_on
	update_camera()

func _on_load_pressed():
	var screen_size := Vector2i(2560, 1440)
	var size := screen_size / 2
	$FileDialog.popup(Rect2i((screen_size - size) / 2, size))


func _on_file_dialog_file_selected(path: String):
	var model = FileAccess.open(path, FileAccess.READ)
	
	var filename := path.split("/")[-1]
	var file_extension := filename.substr(filename.find("."))
	if file_extension == ".txt":
		filename = filename.trim_suffix(file_extension) + ".off"
		var saved := FileAccess.open("res://" + filename, FileAccess.WRITE)
		
		for i in model.get_length():
			saved.store_8(model.get_8())
		saved.close()
	
	visual.mesh = ResourceLoader.load("res://" + filename, "off" if file_extension == ".txt" else file_extension.substr(1))
	
	basis = Projection.IDENTITY
