# InventorySlot.gd
extends PanelContainer # Or TextureRect, or Button, etc.

@export var item: Item = null:
	set(value):
		item = value
		if is_node_ready():
			update_display()

# This function is guaranteed to run AFTER the node and its children are ready.
# This is the perfect place for the initial setup.
func _ready():
	update_display()

func update_display():
	# Update the TextureRect's texture and potentially a label for the item name
	if item:
		$ItemTexture.texture = item.item_texture
		$ItemTexture.visible = true
	else:
		$ItemTexture.texture = null
		$ItemTexture.visible = false

# In InventorySlot.gd

func _get_drag_data(at_position: Vector2) -> Variant:
	if item == null:
		return null

	var drag_data = {}
	drag_data["type"] = "inventory_item"
	drag_data["item_resource"] = item
	drag_data["source_slot"] = self

	# --- DRAG PREVIEW FIX ---
	# Create a wrapper so we can control the offset
	var drag_preview_wrapper = Control.new()
	
	# Create the texture and make it a child of the wrapper
	var drag_preview_texture = TextureRect.new()
	drag_preview_texture.texture = item.item_texture
	drag_preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview_texture.custom_minimum_size = Vector2(64, 64) # Or your slot size
	drag_preview_wrapper.add_child(drag_preview_texture)
	
	# Set the texture's position so it's centered on the mouse
	drag_preview_texture.position = -drag_preview_texture.custom_minimum_size / 2
	
	# Set the wrapper as the preview
	set_drag_preview(drag_preview_wrapper)
	# --- END FIX ---

	# Temporarily hide the item in the original slot
	$ItemTexture.visible = false

	return drag_data
	
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# An inventory slot can accept any item.
	return data is Dictionary and data.has("type") and data["type"] == "inventory_item"

func _drop_data(at_position: Vector2, data: Variant):
	var new_item: Item = data["item_resource"]
	var source_slot = data["source_slot"]
	
	# Check what kind of slot the item came from
	if source_slot is EquipSlot:
		# The source was a robot slot. It uses '.current_equipped_item'.
		# Send our current item (if any) back to the robot slot.
		source_slot.current_equipped_item = self.item
	else:
		# The source was another inventory slot. It uses '.item'.
		# Send our current item (if any) back to the other inventory slot.
		source_slot.item = self.item

	# Now, take the new item that was dropped on us.
	self.item = new_item
	
	# Update the visuals for both slots to reflect the change.
	source_slot.update_display()
	self.update_display()
