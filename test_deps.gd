extends Node

func _ready():
	var deps = ResourceLoader.get_dependencies("res://ui/season_hub.tscn")
	print("Dependencies for season_hub.tscn: ", deps.size())
	for d in deps:
		print(" - ", d)
	
	deps = ResourceLoader.get_dependencies("res://scenes/court/court.tscn")
	print("Dependencies for court.tscn: ", deps.size())
	for d in deps:
		print(" - ", d)
	
	get_tree().quit()
