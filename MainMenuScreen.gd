extends PanelContainer


func _on_button_pressed() -> void:
		# Get this node's parent (which is the ScreenManager)
	# and call its show_screen function.
	get_parent().show_screen("game")


func _on_equip_screen_pressed() -> void:
	# Tell the parent ScreenManager to show the equipment screen
	get_parent().show_screen("equipment")
