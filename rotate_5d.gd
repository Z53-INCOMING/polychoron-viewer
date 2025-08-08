extends "res://mesh_instance_5d.gd"

func _process(delta):
	euler_5D.x += Input.get_axis("left", "right") * delta
	euler_5D.y += Input.get_axis("down", "up") * delta
	euler_5D.z += Input.get_axis("forward", "backward") * delta
	euler_5D.w += Input.get_axis("kata", "ana") * delta
	super(delta)
