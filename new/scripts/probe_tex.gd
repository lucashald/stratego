extends SceneTree
func _initialize() -> void:
	for path in ["res://assets/frame_light.png", "res://assets/frame_medium.png", "res://assets/frame_heavy.png"]:
		var exists := ResourceLoader.exists(path)
		var tex: Texture2D = load(path) if exists else null
		print(path, " exists=", exists, " loaded=", tex != null, " size=", tex.get_size() if tex else "n/a")
	print("weight key: '", StrategoGame.WEIGHT_LIGHT, "'")
	quit()
