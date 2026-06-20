extends TextureRect

var offset_x := 0.0

func _process(delta):
	offset_x += 20 * delta
	material.set_shader_parameter("offset", offset_x)
