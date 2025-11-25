# equip_slot.gd
extends PanelContainer
class_name EquipSlot

signal item_equipped(item)
signal item_unequipped(item)

# This will hold a reference to our main screen script. It starts as null.
var main_screen = null

@export var current_equipped_item: Item = null:
	set(value):
		var old_item = current_equipped_item
		current_equipped_item = value
		if is_node_ready():
			update_display()
			if current_equipped_item != old_item:
				if current_equipped_item:
					emit_signal("item_equipped", current_equipped_item)
				else:
					emit_signal("item_unequipped", old_item)

@export var allowed_item_types: Array[String] = []

# This function is guaranteed to run when the node is ready.
func _ready():
	# --- THIS IS THE NEW, ROBUST WAY TO FIND THE PARENT ---
	# We search UPWARDS from this node until we find the one with the correct script.
	var current_node = self
	while current_node.get_parent() != null:
		current_node = current_node.get_parent()
		if current_node is RobotEquipScreen:
			main_screen = current_node
			break # Stop searching once we find it
	
	update_display()

func update_display():
	var texture_rect = $ItemTexture
	if current_equipped_item and texture_rect:
		texture_rect.texture = current_equipped_item.item_texture
		texture_rect.visible = true
	elif texture_rect:
		texture_rect.texture = null
		texture_rect.visible = false

# --- DRAG AND DROP LOGIC ---

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("type") and data["type"] == "inventory_item"

func _drop_data(at_position: Vector2, data: Variant):
	var new_item: Item = data["item_resource"]
	var source_slot = data["source_slot"]

	if allowed_item_types.has(new_item.item_type):
		# SUCCESS: Equip the item
		if source_slot is EquipSlot:
			source_slot.current_equipped_item = self.current_equipped_item
		else:
			# The source was an INVENTORY slot.
			# 1. Remove the new item from the global inventory list
			RobotState.inventory.erase(new_item)
			
			# 2. If we are swapping (we have an item), add our old item to the global inventory
			if self.current_equipped_item:
				RobotState.inventory.append(self.current_equipped_item)
			
			# 3. Notify everyone that inventory changed (this will refresh the inventory grid)
			RobotState.emit_signal("inventory_changed")
			
			# We don't need to manually update source_slot.item because the signal 
			# will cause the entire grid to rebuild.
		
		self.current_equipped_item = new_item
		
		# source_slot.update_display() # Redundant if rebuilding inventory, but harmless for EquipSlot swap
		if source_slot is EquipSlot:
			source_slot.update_display()
			
		self.update_display()
		
		# Now that main_screen is correctly found, this will work.
		if main_screen:
			main_screen.update_robot_stats()
	else:
		# FAILURE: Return the item
		# We must also tell the source to update its display to reappear.
		source_slot.update_display()

func _get_drag_data(at_position: Vector2) -> Variant:
	if current_equipped_item == null:
		return null

	var drag_data = {}
	drag_data["type"] = "inventory_item"
	drag_data["item_resource"] = current_equipped_item
	drag_data["source_slot"] = self
	
	var drag_preview_wrapper = Control.new()
	var drag_preview_texture = TextureRect.new()
	drag_preview_texture.texture = current_equipped_item.item_texture
	drag_preview_texture.custom_minimum_size = Vector2(64, 64)
	drag_preview_wrapper.add_child(drag_preview_texture)
	drag_preview_texture.position = - drag_preview_texture.custom_minimum_size / 2
	set_drag_preview(drag_preview_wrapper)
	
	# Don't clear the item data yet! Just hide the visual.
	# The target slot will handle clearing/swapping the data in _drop_data.
	# If the drag is cancelled, NOTIFICATION_DRAG_END will restore visibility.
	var texture_rect = $ItemTexture
	if texture_rect:
		texture_rect.visible = false
	
	# self.current_equipped_item = null # REMOVED: Caused item loss on cancel
	
	# And this will now work too.
	if main_screen:
		main_screen.update_robot_stats()

	return drag_data

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# When drag ends (successful or not), we refresh our display.
		# If successful, _drop_data in the target has already updated our 'current_equipped_item'.
		# If failed, 'current_equipped_item' is untouched.
		# In both cases, update_display() shows the correct state.
		update_display()

# --- NEW METHODS FOR CLICK-EQUIP SUPPORT ---

func can_accept_item(item: Item) -> bool:
	if allowed_item_types.is_empty():
		return true
	return allowed_item_types.has(item.item_type)

func equip_item(item: Item):
	# If we already have an item, we might need to handle swapping or unequipping
	# But for the simple "click to equip" logic, we just overwrite.
	# The caller (RobotEquipScreen) handles removing it from inventory.
	self.current_equipped_item = item
	update_display()
	
	# Update stats
	# Update stats
	if main_screen:
		main_screen.update_robot_stats()

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_equipped_item:
			# Unequip!
			var item_to_remove = current_equipped_item
			self.current_equipped_item = null
			
			# Return to inventory
			RobotState.inventory.append(item_to_remove)
			RobotState.emit_signal("inventory_changed")
			
			# Update stats
			if main_screen:
				main_screen.update_robot_stats()
			
			get_viewport().set_input_as_handled()
