extends Node
class_name Juice

# Configuration
@export var hover_scale: Vector2 = Vector2(1.05, 1.05)
@export var idle_amplitude: Vector2 = Vector2(0, -2.0)
@export var idle_speed: float = 2.0
@export var rotation_amplitude: float = 0.0 # Degrees

# Internal
var _target: Control
var _base_scale: Vector2
var _base_pos: Vector2
var _time_offset: float = 0.0
var _is_hovering: bool = false

func _ready():
	_target = get_parent()
	if not _target is Control:
		push_warning("Juice node expects a Control parent!")
		set_process(false)
		return
		
	# Wait one frame to ensure layout is settled
	await get_tree().process_frame
	
	_base_scale = _target.scale
	_base_pos = _target.position
	
	# Randomize start time for organic feel
	_time_offset = randf() * 100.0
	
	# Connect signals
	_target.mouse_entered.connect(_on_mouse_entered)
	_target.mouse_exited.connect(_on_mouse_exited)
	
	# Ensure pivot is center for scaling
	_target.pivot_offset = _target.size / 2.0
	_target.resized.connect(func(): _target.pivot_offset = _target.size / 2.0)

func _process(delta):
	var time = Time.get_ticks_msec() / 1000.0 + _time_offset
	
	# Idle Animation (Sine Wave)
	var idle_offset = Vector2(
		sin(time * idle_speed) * idle_amplitude.x,
		sin(time * idle_speed) * idle_amplitude.y
	)
	
	# Apply Position
	_target.position = _base_pos + idle_offset
	
	# Apply Rotation (Subtle wobble)
	if rotation_amplitude > 0:
		_target.rotation_degrees = sin(time * idle_speed * 0.5) * rotation_amplitude

func _on_mouse_entered():
	_is_hovering = true
	var tween = create_tween()
	tween.tween_property(_target, "scale", _base_scale * hover_scale, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_mouse_exited():
	_is_hovering = false
	var tween = create_tween()
	tween.tween_property(_target, "scale", _base_scale, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
