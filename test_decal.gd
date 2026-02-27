@tool
extends SceneTree

func _init():
	var decal = Decal.new()
	print(decal.get_property_list())
	quit()
