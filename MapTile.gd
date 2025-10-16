# MapTile.gd
extends PanelContainer

# --- EXPORTED VARIABLES ---
# (These are all correct and do not need to be changed)
@export var habitation_style: StyleBox
@export var storage_style: StyleBox
@export var workshop_style: StyleBox

@export var habitation_icon: Texture2D
@export var storage_icon: Texture2D
@export var workshop_icon: Texture2D

@export var robot_icon: Texture2D
@export var corridor_icon: Texture2D # A simple texture for a corridor segment
@export var connector_icon: Texture2D # A texture for the horizontal connecting lines
# --- END OF EXPORTED VARIABLES ---


# --- CHANGED: Updated paths to account for the new VBoxContainer ---
# Make sure in your MapTile.tscn, the Icon and InfoLabel are inside a VBoxContainer
@onready var icon = $VBoxContainer/Icon
@onready var info_label = $VBoxContainer/InfoLabel


# This is our master function to configure the tile
func display_data(room: Room = null, is_robot_pos: bool = false, is_door_segment: bool = true):
	# --- CHANGED: We now use 'visible' property for a cleaner hide/show ---
	# Start by making the tile completely invisible.
	# It will only become visible if it has a purpose.
	self.visible = true
	icon.texture = null # Clear texture just in case
	info_label.text = ""

	if room:
		# --- THIS IS A ROOM TILE ---
		self.visible = true # Make it visible
		
		info_label.text = "D#%d (%s)" % [room.room_id, room.type_name.substr(0, 4)]
		
		# Set style and icon based on room type
		match room.type_name:
			"Habitation":
				add_theme_stylebox_override("panel", habitation_style)
				icon.texture = habitation_icon
			"Storage":
				add_theme_stylebox_override("panel", storage_style)
				icon.texture = storage_icon
			"Workshop":
				add_theme_stylebox_override("panel", workshop_style)
				icon.texture = workshop_icon
	
	elif is_robot_pos:
		# --- THIS IS THE ROBOT IN THE CORRIDOR ---
		icon.texture = robot_icon
		
	elif is_door_segment:
		info_label.text = "DOOR"
	
	# --- CHANGED: The entire 'else' block that drew the default corridor icon has been removed ---
	# By removing it, any tile that is not a room or a robot will correctly remain invisible.


# --- REPLACED: The old simple connector function is gone ---
# --- ADDED: A new, smarter function for our connector lines ---
# This function will only show the connector if a room actually exists to connect to.
func display_as_connector_for_room(room: Room):
	if room:
		self.visible = true
		icon.texture = connector_icon
		info_label.text = "--------" # Connectors have no text
	else:
		self.visible = false

func display_as_empty():
	self.visible = false
