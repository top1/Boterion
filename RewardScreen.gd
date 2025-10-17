# RewardScreen.gd
extends Control

@onready var loot_summary_label = %LootSummaryLabel
@onready var continue_button = %ContinueButton

func _ready():
	continue_button.pressed.connect(_on_continue_pressed)

# Diese Funktion wird vom ScreenManager aufgerufen, um die Daten zu übergeben
func show_rewards(collected_loot: Dictionary):
	var summary_text = "Items Recovered:\n"
	summary_text += "--------------------\n"
	if collected_loot.is_empty():
		summary_text += "Nothing was recovered."
	else:
		for item_name in collected_loot:
			summary_text += "- %s: %d\n" % [item_name.capitalize(), collected_loot[item_name]]
	
	loot_summary_label.text = summary_text

func _on_continue_pressed():
	# Finde den ScreenManager und sage ihm, zum Hauptmenü zurückzukehren
	RobotState.start_new_day()
	get_tree().get_first_node_in_group("ScreenManager").show_screen("main_menu")
