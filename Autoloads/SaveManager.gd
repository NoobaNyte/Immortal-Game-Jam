extends Node

const SAVE_PATH = "user://game_data.json"

# Default data structure if no file exists yet
# this is the var that gets updated (when you add players / adjust score)
# when you save it, it writes to the players.json file
# when you load it, it reads whatever is on the players.json file and makes this var that
var game_data = {
	"players": [
		##{"name": "Guest", "balance": 1000.0}
	],
	"game_state": [
		##{"game_title": "Title", "state": "IDLE, SPINNING, FEATURE", "mode": "DEFAULT, FEATURE"}
	]
}

func add_player(player_name: String, starting_balance: float = 1000.0) -> void:
	print("adding player: " + player_name + " to players list!")
	game_data["players"].append({
		"name": player_name,
		"balance": starting_balance
	})
	
	## make it actually write to the jsonfile
	save_game()

# 1. SAVE DATA TO DISK
func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# Convert our dictionary to a JSON string and store it
		var json_string = JSON.stringify(game_data, "\t")
		file.store_string(json_string)
		print("Game successfully saved to: ", OS.get_user_data_dir())

# 2. LOAD DATA FROM DISK
func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			var json = JSON.new()
			var parse_result = json.parse(json_text)
			
			if parse_result == OK:
				game_data = json.get_data()
				print("Game successfully loaded!")
			else:
				print("JSON Parse Error on load.")
	else:
		print("No save file found. Creating default data...")
		save_game() # Creates the initial file
