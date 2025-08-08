extends Node4D

var mouse_sensitivity := 0.004 * (2560.0 / float(ProjectSettings.get_setting("display/window/size/viewport_width")))

@onready var camera = $Camera
@onready var visual = $Visual

var zoom := 1.0

var line_thickness := 8.0

var camera_fade_start := 3.5
var camera_fade_end := 5.0
var camera_w_fade_distance := 1.0
var camera_w_fade_slope := 0.0
var camera_w_fade_distance_focus := 1.0
var camera_w_fade_slope_focus := 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.projection_type = Camera4D.PROJECTION4D_PERSPECTIVE_4D

func _process(delta):
	camera.w_fade_distance = lerpf(camera.w_fade_distance, 0.5 if Input.is_action_pressed("focus") else 1.0, 1.0 - pow(2.0, -delta / 0.1))

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if Input.is_key_pressed(KEY_SHIFT):
				line_thickness *= 8.0 / 7.0
			else:
				zoom *= 7.0 / 6.0
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_SHIFT):
				line_thickness *= 7.0 / 8.0
			else:
				zoom *= 6.0 / 7.0
		visual.material_override.line_thickness = line_thickness
	
	if event is InputEventMouseMotion:
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
