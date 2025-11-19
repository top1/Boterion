# RewardScreen.gd
extends Control

@onready var loot_summary_label = %LootSummaryLabel
@onready var continue_button = %ContinueButton

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)

func _on_continue_pressed():
	# Save the loot!
	# We need to access the loot data. The show_rewards function only displayed it.
	# We should probably store it temporarily or pass it here.
	# Ideally, RobotState should have accumulated it, or we pass it to add_resources.
	# Since show_rewards took the dict, let's assume we can't access it here easily unless we stored it.
	# BUT, the user might have clicked "continue" without us saving it if we don't store it.
	# Let's modify show_rewards to store the current loot in a variable.
	if _current_loot:
		RobotState.add_resources(_current_loot)
	
	# Finde den ScreenManager und sage ihm, zum Hauptmenü zurückzukehren
	RobotState.start_new_day()
	get_tree().get_first_node_in_group("ScreenManager").show_screen("game")

var _current_loot: Dictionary = {}

# Diese Funktion wird vom ScreenManager aufgerufen, um die Daten zu übergeben
func show_rewards(collected_loot: Dictionary):
	_current_loot = collected_loot
	var summary_text = "Items Recovered:\n"
	summary_text += "--------------------\n"
	if collected_loot.is_empty():
		summary_text += "Nothing was recovered."
	else:
		for item_name in collected_loot:
			summary_text += "- %s: %d\n" % [item_name.capitalize(), collected_loot[item_name]]
	
	loot_summary_label.text = summary_text
