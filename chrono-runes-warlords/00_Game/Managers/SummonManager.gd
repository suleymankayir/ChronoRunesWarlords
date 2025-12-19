class_name SummonManager extends Node

# List of all characters
var all_characters: Array[CharacterData] = []

func _ready() -> void:
	load_database()

# Finds .tres files in folder and adds to list
func load_database() -> void:
	var path = "res://00_Game/Resources/Characters/"
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				# Load file and add to list
				var hero = load(path + "/" + file_name) as CharacterData
				if hero:
					all_characters.append(hero)
			
			file_name = dir.get_next()
			
	print("GACHA SYSTEM READY. Pool has ", all_characters.size(), " characters.")

# Selects a random character
func pull_random_hero() -> CharacterData:
	if all_characters.is_empty():
		push_error("ERROR: Character pool empty! Check .tres files.")
		return null
		
	return all_characters.pick_random()
