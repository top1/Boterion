extends Control

signal intro_finished

@onready var ship_pivot = %ShipPivot
@onready var title_label = %TitleLabel
@onready var start_label = %StartLabel

func _ready():
	# Ensure we can process input
	set_process_input(true)
	
	# Connect invisible button
	if has_node("UI/StartButton"):
		$UI/StartButton.pressed.connect(_finish_intro)
	
	_build_ship()
	_build_stars()
	_setup_environment()
	
	# FORCE CAMERA
	var cam = $SubViewportContainer/SubViewport/World3D/Camera3D
	if cam:
		cam.look_at_from_position(Vector3(-12, 1, 0), Vector3(0, 0, 0), Vector3.UP)
		print("DEBUG: Camera positioned at ", cam.global_position, " looking at 0,0,0")
	else:
		print("DEBUG: Camera not found!")
	
	# Initial animation
	var tween = create_tween()
	title_label.modulate.a = 0.0
	start_label.modulate.a = 0.0
	tween.tween_property(title_label, "modulate:a", 1.0, 2.0)
	tween.tween_property(start_label, "modulate:a", 1.0, 1.0).set_delay(1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Pulse the start label
	var pulse = create_tween().set_loops()
	pulse.tween_property(start_label, "modulate:a", 0.5, 1.0)
	pulse.tween_property(start_label, "modulate:a", 1.0, 1.0)


func _process(delta):
	# Rotate the ship - "rolling" on its forward axis (Z) and slightly pitching (X)
	if ship_pivot:
		# Rotating around local Z axis (rolling)
		ship_pivot.rotate_object_local(Vector3(0, 0, 1), 0.5 * delta)
		
		# Slight wobble
		# ship_pivot is a Node3D, so rotation.x is valid
		ship_pivot.rotation.x = sin(Time.get_ticks_msec() * 0.001) * 0.1 # Small wobble

func _input(event):
	# Global input check - accepts ANY key or mouse button
	if event is InputEventKey and event.pressed:
		_finish_intro()
	elif event is InputEventMouseButton and event.pressed:
		_finish_intro()

func _finish_intro():
	set_process_input(false)
	emit_signal("intro_finished")

func _setup_environment():
	var world_env = $SubViewportContainer/SubViewport/World3D/WorldEnvironment
	if world_env and world_env.environment:
		world_env.environment.background_mode = Environment.BG_COLOR
		world_env.environment.background_color = Color.BLACK
		# Tint ambient light slightly blue
		world_env.environment.ambient_light_color = Color(0.05, 0.05, 0.1)

func _build_stars():
	var particles = CPUParticles3D.new()
	particles.amount = 2000 # MORE STARS
	particles.lifetime = 2.0 # Faster cycle
	particles.preprocess = 2.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(50, 20, 100) # Huge field
	particles.direction = Vector3(0, 0, -1) # Fly backwards
	particles.spread = 0.0
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 60.0
	
	# Pixel art style stars (tiny squares)
	particles.mesh = BoxMesh.new()
	particles.mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat_star = StandardMaterial3D.new()
	mat_star.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_star.albedo_color = Color.WHITE
	particles.mesh.material = mat_star
	
	# Center on ship (0,0,0)
	particles.position = Vector3(0, 0, 0)
	
	$SubViewportContainer/SubViewport/World3D.add_child(particles)

func _build_ship():
	if not ship_pivot: return
	
	# Clear existing children if any (re-entrance safety)
	for child in ship_pivot.get_children():
		child.queue_free()
	
	# -- MATERIALS --
	# Dark hull, slightly metallic/rough
	var mat_hull = StandardMaterial3D.new()
	mat_hull.albedo_color = Color(0.1, 0.1, 0.12)
	mat_hull.metallic = 0.5
	mat_hull.roughness = 0.7
	
	# Blue Glow (Engines/Shield edges)
	var mat_glow_blue = StandardMaterial3D.new()
	mat_glow_blue.albedo_color = Color(0.0, 0.6, 1.0)
	mat_glow_blue.emission_enabled = true
	mat_glow_blue.emission = Color(0.0, 0.6, 1.0)
	mat_glow_blue.emission_energy_multiplier = 5.0
	
	# Shield Front
	var mat_shield_front = StandardMaterial3D.new()
	mat_shield_front.albedo_color = Color(0.0, 0.8, 1.0, 0.3)
	mat_shield_front.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_shield_front.emission_enabled = true
	mat_shield_front.emission = Color(0.0, 0.8, 1.0)
	mat_shield_front.emission_energy_multiplier = 2.0
	mat_shield_front.rim_enabled = true
	mat_shield_front.rim = 0.5
	
	# -- GEOMETRY: CIGARETTE SHAPE --
	
	# -- GEOMETRY: INDUSTRIAL TUNNEL SHIP --
	
	# 1. Main Fusealage (Segmented)
	# Segment 1 (Rear)
	var body1 = MeshInstance3D.new()
	body1.mesh = CylinderMesh.new()
	body1.mesh.top_radius = 0.8
	body1.mesh.bottom_radius = 0.9
	body1.mesh.height = 1.5
	body1.rotation_degrees.x = 90
	body1.position = Vector3(0, 0, -1.5)
	body1.material_override = mat_hull
	ship_pivot.add_child(body1)
	
	# Segment 2 (Mid - Thinner)
	var body2 = MeshInstance3D.new()
	body2.mesh = CylinderMesh.new()
	body2.mesh.top_radius = 0.6
	body2.mesh.bottom_radius = 0.6
	body2.mesh.height = 1.5
	body2.rotation_degrees.x = 90
	body2.position = Vector3(0, 0, 0.0)
	body2.material_override = mat_hull
	ship_pivot.add_child(body2)
	
	# Segment 3 (Front - Bulk)
	var body3 = MeshInstance3D.new()
	body3.mesh = CylinderMesh.new()
	body3.mesh.top_radius = 0.7
	body3.mesh.bottom_radius = 0.7
	body3.mesh.height = 1.0
	body3.rotation_degrees.x = 90
	body3.position = Vector3(0, 0, 1.25)
	body3.material_override = mat_hull
	ship_pivot.add_child(body3)
	
	# Connector Rings
	var ring_pos = [-0.75, 0.75]
	for z in ring_pos:
		var ring = MeshInstance3D.new()
		ring.mesh = BoxMesh.new() # Hexagonal feel via thin boxes? No, Cylinder ring checks out.
		ring.mesh = CylinderMesh.new()
		ring.mesh.top_radius = 0.85
		ring.mesh.bottom_radius = 0.85
		ring.mesh.height = 0.2
		ring.rotation_degrees.x = 90
		ring.position = Vector3(0, 0, z)
		ring.material_override = mat_hull
		ship_pivot.add_child(ring)

	# 2. Side structures (Solar panels / Heat sinks) - Breaks silhouette
	var panel_l = MeshInstance3D.new()
	panel_l.mesh = BoxMesh.new()
	panel_l.mesh.size = Vector3(0.1, 3.0, 1.5) # Thin, wide, long
	panel_l.position = Vector3(-1.0, 0, 0)
	panel_l.material_override = mat_hull
	ship_pivot.add_child(panel_l)
	
	var panel_r = MeshInstance3D.new()
	panel_r.mesh = BoxMesh.new()
	panel_r.mesh.size = Vector3(0.1, 3.0, 1.5)
	panel_r.position = Vector3(1.0, 0, 0)
	panel_r.material_override = mat_hull
	ship_pivot.add_child(panel_r)


	# 3. Main Engine Block (Rear)
	var engine_block = MeshInstance3D.new()
	engine_block.mesh = BoxMesh.new()
	engine_block.mesh.size = Vector3(2.0, 2.0, 1.0)
	engine_block.position = Vector3(0, 0, -2.5)
	engine_block.material_override = mat_hull
	ship_pivot.add_child(engine_block)

	# Thrusters (4 corners of block)
	var thruster_offsets = [
		Vector3(-0.6, 0.6, -0.5),
		Vector3(0.6, 0.6, -0.5),
		Vector3(-0.6, -0.6, -0.5),
		Vector3(0.6, -0.6, -0.5)
	]
	
	for offset in thruster_offsets:
		var t = MeshInstance3D.new()
		t.mesh = CylinderMesh.new()
		t.mesh.top_radius = 0.25
		t.mesh.bottom_radius = 0.35
		t.mesh.height = 0.8
		t.rotation_degrees.x = 90
		# Position relative to engine block center (-2.5) => offset.z is local
		t.position = Vector3(offset.x, offset.y, -3.0)
		t.material_override = mat_hull
		ship_pivot.add_child(t)
		
		# Particles - ENGINE PLUME
		var flame = CPUParticles3D.new()
		flame.amount = 200 # Very Dense
		flame.lifetime = 1.2 # Long trail
		
		# Create a glowing material for the particles
		var mat_flame = StandardMaterial3D.new()
		mat_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_flame.vertex_color_use_as_albedo = true
		mat_flame.albedo_color = Color(1, 1, 1) # Let particle color dictate
		
		var mesh_p = BoxMesh.new()
		mesh_p.size = Vector3(0.06, 0.06, 0.06)
		mesh_p.material = mat_flame
		flame.mesh = mesh_p
		
		# Direction: Backwards (Local -Y = Global -Z)
		flame.direction = Vector3(0, -1, 0)
		flame.spread = 2.0 # Tight beam
		flame.gravity = Vector3.ZERO
		flame.initial_velocity_min = 12.0
		flame.initial_velocity_max = 18.0
		flame.color = Color(0.1, 0.7, 1.0) # Bright Cyan-Blue
		flame.scale_amount_min = 1.0
		flame.scale_amount_max = 3.0
		
		flame.position = Vector3(0, -0.4, 0)
		t.add_child(flame)

	# 4. Front Shield (Disc/Dome) - FLATTER
	var shield_mount = MeshInstance3D.new()
	shield_mount.mesh = CylinderMesh.new()
	shield_mount.mesh.top_radius = 0.5
	shield_mount.mesh.bottom_radius = 0.7
	shield_mount.mesh.height = 0.5
	shield_mount.rotation_degrees.x = 90
	shield_mount.position = Vector3(0, 0, 2.0)
	shield_mount.material_override = mat_hull
	ship_pivot.add_child(shield_mount)

	var shield_mesh = MeshInstance3D.new()
	# Use a very flat sphere (oblate spheroid) or a cylinder cap
	shield_mesh.mesh = SphereMesh.new()
	shield_mesh.mesh.radius = 1.5
	shield_mesh.mesh.height = 0.5 # Flattened significantly
	shield_mesh.mesh.is_hemisphere = true
	shield_mesh.rotation_degrees.x = 90
	shield_mesh.position = Vector3(0, 0, 2.3)
	shield_mesh.material_override = mat_shield_front
	ship_pivot.add_child(shield_mesh)
