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
		
	# Add Juice Animation (Breathing)
	var juice = Juice.new()
	juice.name = "Juice"
	juice.hover_scale = Vector2(1.1, 1.1)
	juice.idle_amplitude = Vector2(0, 0) # No movement, just scale pulse
	juice.idle_speed = 1.0 + randf()
	add_child(juice)
	
	update_particles()

func update_particles():
	# Clear existing particles first
	for child in get_children():
		if child is CPUParticles2D:
			child.queue_free()
			
	if not room_data:
		return

	# 1. Ancient Factory Particles (Gold) - Requires Ancient Scanner
	if room_data.type == RoomData.RoomType.FACTORY:
		if RobotState.has_artifact_effect(Artifact.EffectType.REVEAL_ANCIENT_FACTORY):
			_add_particles(Color(1, 0.8, 0.2)) # Gold
	
	# 2. Blueprint Particles (Rarity Color) - Requires Blueprint Scanner
	elif room_data.loot_pool.blueprints.current > 0:
		if RobotState.has_artifact_effect(Artifact.EffectType.REVEAL_BLUEPRINTS):
			var highest_rarity = _get_highest_blueprint_rarity()
			var color = _get_rarity_color(highest_rarity)
			_add_particles(color)

func _get_highest_blueprint_rarity() -> String:
	var rarities = ["COMMON", "RARE", "EPIC", "LEGENDARY"]
	var highest_idx = -1
	var highest_rarity = "COMMON"
	
	for item in room_data.blueprint_items:
		var idx = rarities.find(item.rarity)
		if idx > highest_idx:
			highest_idx = idx
			highest_rarity = item.rarity
	
	return highest_rarity

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"COMMON": return Color(0.8, 0.8, 0.8) # Gray/White
		"RARE": return Color(0.2, 0.6, 1.0) # Blue
		"EPIC": return Color(0.6, 0.2, 1.0) # Purple
		"LEGENDARY": return Color(1.0, 0.5, 0.0) # Orange
		_: return Color(1, 1, 1)

func _add_particles(color: Color):
	var particles = CPUParticles2D.new()
	particles.amount = 40 # Increased slightly
	particles.lifetime = 0.4 # "Slower flicker"
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(20, 25)
	particles.gravity = Vector2(0, -10)
	particles.scale_amount_min = 1.8
	particles.scale_amount_max = 3.0
	particles.color = color
	particles.position = size / 2.0
	particles.local_coords = false # Keep trail effect
	
	# Add Gradient for smooth fade out (fixes "flickering")
	var gradient = Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 1.0)) # Start opaque
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0)) # End transparent
	particles.color_ramp = gradient
	
	add_child(particles)

func _on_pressed():
	if room_data:
		# Hier verwenden wir 'self', um die Referenz auf diesen spezifischen Button zu senden.
		emit_signal("room_selected", room_data, self)
		# Or custom signal if defined:
		# emit_signal("room_selected", self)

# --- TILT PHYSICS ---
var _target_tilt: float = 0.0
var _angular_velocity: float = 0.0
const SPRING_STIFFNESS = 150.0
const SPRING_DAMPING = 6.0

func apply_tilt(angle: float):
	_target_tilt = angle

func _process(delta):
	# Spring Physics: Hooke's Law with Damping
	# Force = -k * displacement - d * velocity
	var displacement = rotation_degrees - _target_tilt
	var acceleration = (-SPRING_STIFFNESS * displacement) - (SPRING_DAMPING * _angular_velocity)
	
	_angular_velocity += acceleration * delta
	rotation_degrees += _angular_velocity * delta
	
	# Clamp to avoid exploding physics if delta spikes
	if abs(rotation_degrees) > 90:
		rotation_degrees = clamp(rotation_degrees, -90, 90)
		_angular_velocity = 0

# Diese Funktion kümmert sich um die gesamte visuelle Darstellung.
func _update_display():
	# 2. Aktualisiere die Textur
	if room_data.is_scanned:
		# Wenn der Raum gescannt ist, suche die richtige Textur aus dem Dictionary
		room_texture_rect.texture = ROOM_TEXTURES.get(room_data.type, ROOM_TEXTURES[RoomData.RoomType.STANDARD])
	else:
		# Wenn nicht, benutze die "undiscovered" Textur
		# Wenn nicht, benutze die "undiscovered" Textur
		room_texture_rect.texture = UNDISCOVERED_TEXTURE

func play_scan_animation():
	# 1. Start setup: Ensure we are still showing the "unknown" state or just start the effect
	var tween = create_tween()
	
	# 2. Animation: Scale up and flash
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(2, 2, 2), 0.2) # Flash bright
	
	# 3. Mid-point: Switch texture (Data should be updated by now)
	tween.tween_callback(_update_display)
	
	# 4. Animation: Scale back and normalize color
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(1, 1, 1), 0.3)
