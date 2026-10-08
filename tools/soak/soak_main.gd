extends SceneTree
## Soak harness entry: loads the real main scene, then adds a monitor that
## logs once a minute and, by --soak-mode, pokes the game (pops, throws,
## specials, behaviours). Nothing in the project is changed.

func _initialize() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var mon = load(get_script().resource_path.get_base_dir().path_join("soak_monitor.gd")).new()
	mon.main = main
	root.add_child(mon)
