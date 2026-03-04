extends SceneTree
func _init():
	var scene = load("res://ui/season_setup.tscn")
	if not scene:
		print("FAILED TO LOAD SCENE")
	else:
		print("SCENE LOADED SUCCESSFULLY")
	quit()
