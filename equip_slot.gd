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
			source_slot.item = self.current_equipped_item
		
		self.current_equipped_item = new_item
		
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
	drag_preview_texture.position = -drag_preview_texture.custom_minimum_size / 2
	set_drag_preview(drag_preview_wrapper)
	
	self.current_equipped_item = null
	
	# And this will now work too.
	if main_screen:
		main_screen.update_robot_stats()

	return drag_data
