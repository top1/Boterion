# RobotPanel.gd
extends Control

# This function is called when you drop an item on this panel.
func _drop_data(at_position: Vector2, data: Variant):
	# A drop here is a "cancel". We must return the item to its source.
	var source_slot = data["source_slot"]
	var item_resource: Item = data["item_resource"]
	
	# Restore the item data to the correct variable in the source slot.
	if source_slot is EquipSlot:
		source_slot.current_equipped_item = item_resource
	else:
		source_slot.item = item_resource
	
	# Tell the source slot to update its visuals.
	source_slot.update_display()
	
	# --- THIS IS THE CORRECT AND FINAL FIX ---
	# Get this node's parent (MainLayout), then get THAT node's parent (the root Control).
	# This is the most direct and reliable way to find the main screen.
	var main_screen = get_parent().get_parent()
	main_screen.update_robot_stats()


# This function is needed to make this panel a valid place to drop things.
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("type") and data["type"] == "inventory_item"
