# RoomBlock.gd
extends Button

signal room_selected(room_data: RoomData, room_node: Button)

# Wir entfernen den Aufruf von update_display() aus dem Setter!
var room_data: RoomData:
	set(value):
		room_data = value
		# update_display() WIRD HIER ENTFERNT

@onready var label = %Label

const BLOCK_WIDTH = 50
const BLOCK_HEIGHT = 50

# RoomBlock.gd

func _ready():
	pressed.connect(_on_button_pressed)
	update_display()

# Die update_display() Funktion bleibt exakt gleich.
func update_display():
	# Wenn _ready() diese Funktion aufruft, kann room_data noch null sein,
	# falls es nie gesetzt wurde. Also behalten wir diese Sicherheitsprüfung bei.
	if not room_data:
		return

	# 1. Text des Labels setzen
	label.text = "%s" % [room_data.room_id]

	# 2. Größe des Blocks anpassen
	#custom_minimum_size.x = room_data.size * BLOCK_WIDTH
	custom_minimum_size.x = BLOCK_WIDTH

	# 3. Farbe basierend auf dem Raumtyp ändern
	var type_color = Color.WHITE
	match room_data.type:
		RoomData.RoomType.STANDARD:
			type_color = Color.LIGHT_GRAY
		RoomData.RoomType.TEC:
			# Passende Farbe für TEC
			type_color = Color.PALE_TURQUOISE
		RoomData.RoomType.HABITAT:
			# Passende Farbe für HABITAT
			type_color = Color.PALE_GOLDENROD
	
	self_modulate = type_color

func _on_button_pressed():
	emit_signal("room_selected", room_data, self)
