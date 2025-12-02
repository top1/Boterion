extends Control

@export var slot_index: int = -1
@export var is_storage: bool = false
var artifact = null

func _ready():
	update_display()

func set_artifact(art):
	artifact = art
	update_display()

func update_display():
	var icon = get_node_or_null("Icon")
	if not icon: return
	
	if artifact:
		if artifact.get("icon"):
			icon.texture = artifact.icon
		else:
			icon.texture = preload("res://icon.svg")
		icon.modulate = Color(1, 0.8, 0.2, 1.0)
		tooltip_text = "%s\n%s" % [artifact.name, artifact.description]
	else:
		icon.texture = null
		tooltip_text = "Empty"

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if artifact and not is_storage:
				# Right-click on equipped artifact -> Unequip
				RobotState.unequip_artifact(artifact)
				accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			# Left-click release -> Toggle Equip/Unequip
			# (Using release to allow drag-start on press without triggering this immediately)
			if artifact:
				if is_storage:
					RobotState.equip_artifact(artifact)
				else:
					RobotState.unequip_artifact(artifact)
				accept_event()

func _get_drag_data(_at_position):
	if not artifact: return null
	
	var data = {}
	data["type"] = "artifact"
	data["artifact"] = artifact
	data["source_slot"] = self
	
	var preview = TextureRect.new()
	preview.texture = get_node("Icon").texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(50, 50)
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)
	
	return data

func _can_drop_data(_at_position, data):
	return data is Dictionary and data.get("type") == "artifact"

func _drop_data(_at_position, data):
	var source_slot = data["source_slot"]
	var dropped_artifact = data["artifact"]
	
	if source_slot == self: return
	
	# Logic depends on where we are dropping
	if is_storage:
		# Dropping INTO storage
		if source_slot.is_storage:
			# Reordering in storage? (Not implemented yet, just swap)
			pass
		else:
			# Unequipping (Active -> Storage)
			RobotState.unequip_artifact(dropped_artifact)
	else:
		# Dropping INTO active slot
		if source_slot.is_storage:
			# Equipping (Storage -> Active)
			# Check if we are full? RobotState handles it, but we target a specific slot?
			# RobotState.equip_artifact appends. We might want to set specific slot index.
			# For now, let's just use equip_artifact() which appends.
			# If we want to swap, we need more logic.
			RobotState.equip_artifact(dropped_artifact)
		else:
			# Swapping active slots? (Not implemented)
			pass
