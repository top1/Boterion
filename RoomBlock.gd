# RoomBlock.gd
extends Button

@onready var room_texture_rect = $RoomTexture

# Die Texturen für die verschiedenen Raumtypen
const ROOM_TEXTURES = {
	RoomData.RoomType.STANDARD: preload("res://graphics/rooms/living_s.png"),
	RoomData.RoomType.TEC: preload("res://graphics/rooms/tec_s.png"),
	RoomData.RoomType.HABITAT: preload("res://graphics/rooms/habitat_s.png"),
}
# Die Textur für ungescannte Räume
const UNDISCOVERED_TEXTURE = preload("res://graphics/rooms/undiscovered_s.png")


# KORRIGIERT: 'self' wurde durch 'room_node' ersetzt.
signal room_selected(room_data: RoomData, room_node: Button)

# Wir verwenden einen Setter, damit wir auf die Zuweisung der Daten reagieren können.
var room_data: RoomData:
	set(new_data):
		room_data = new_data
		# Wenn die Daten gesetzt werden, aktualisiere alles.
		if is_inside_tree() and room_data:
			_update_display()

# Diese Funktion wird aufgerufen, wenn der Node zum ersten Mal dem Baum hinzugefügt wird.
# Wir stellen sicher, dass das Display auch aktualisiert wird, falls die Daten schon vorher gesetzt wurden.
func _ready():
	if room_data:
		_update_display()

func _on_pressed():
	if room_data:
		# Hier verwenden wir 'self', um die Referenz auf diesen spezifischen Button zu senden.
		emit_signal("room_selected", room_data, self)

# Diese Funktion kümmert sich um die gesamte visuelle Darstellung.
func _update_display():
	
	# 2. Aktualisiere die Textur
	if room_data.is_scanned:
		# Wenn der Raum gescannt ist, suche die richtige Textur aus dem Dictionary
		room_texture_rect.texture = ROOM_TEXTURES.get(room_data.type, ROOM_TEXTURES[RoomData.RoomType.STANDARD])
	else:
		# Wenn nicht, benutze die "undiscovered" Textur
		room_texture_rect.texture = UNDISCOVERED_TEXTURE
