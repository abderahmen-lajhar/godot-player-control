extends CharacterBody2D

# === exported variables ===
@export var speed : float = 230
@export var acceleration : float = 1500.0
@export var gravity : float = 900.0
@export var jump_velocity : float = -430
@export var low_jump_multiplier : float = 2.0
@export var dash_speed : float = 500.0
@export var dash_time : float = 0.75
@export var roll_speed : float = 230.0
@export var roll_time : float = 0.8
@export var slide_speed : float = 320.0
@export var wall_slide_speed : float = 80.0
@export var wall_jump_velocity : Vector2 = Vector2(250, -380)
@export var coyote_time_max : float = 0.12
@export var jump_buffer_time_max : float = 0.12
@export var sprite_faces_right : bool = true

# === internal state ===
var facing_right : bool = true
var is_dashing : bool = false
var dash_timer : float = 0.0
var air_dash_available : bool = true
var is_rolling : bool = false
var roll_timer : float = 0.0
var is_sliding : bool = false
var is_attacking : bool = false
var is_wall_sliding : bool = false
var attack_combo : int = 0

# timers
var coyote_timer : float = 0.0
var jump_buffer_timer : float = 0.0

# === nodes ===
@onready var sprite : AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	sprite.play("idle")
	sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))

func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_input(delta)
	_check_wall_slide()
	_update_animation()
	move_and_slide()

# ===== gravity + variable jump + coyote =====
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		if velocity.y < 0 and not Input.is_action_pressed("jump"):
			velocity.y += gravity * (low_jump_multiplier - 1) * delta
		coyote_timer -= delta
	else:
		velocity.y = 0
		coyote_timer = coyote_time_max
		air_dash_available = true

# ===== input =====
func _handle_input(delta: float) -> void:
	var input_dir := 0

	if Input.is_action_pressed("ui_left"):
		input_dir -= 1
	if Input.is_action_pressed("ui_right"):
		input_dir += 1

	# smooth movement
	if not (is_dashing or is_rolling or is_sliding or is_attacking):
		if input_dir != 0:
			velocity.x = lerp(velocity.x, input_dir * speed, acceleration * delta / speed)
		else:
			velocity.x = 0

	# flip sprite
	if input_dir != 0 and not is_wall_sliding:
		facing_right = input_dir > 0
		sprite.flip_h = (not facing_right) if sprite_faces_right else facing_right

	# jump buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time_max
	else:
		jump_buffer_timer -= delta

	# jump
	if jump_buffer_timer > 0:
		if coyote_timer > 0:
			velocity.y = jump_velocity
			sprite.play("jump")
			jump_buffer_timer = 0
			coyote_timer = 0
		elif is_wall_sliding:
			_wall_jump()
			jump_buffer_timer = 0

	# dash
	if Input.is_action_just_pressed("dash") and (is_on_floor() or air_dash_available):
		is_dashing = true
		dash_timer = dash_time
		velocity.x = (1 if facing_right else -1) * dash_speed
		sprite.play("dash")
		if not is_on_floor():
			air_dash_available = false

	# roll
	if Input.is_action_just_pressed("roll") and is_on_floor():
		is_rolling = true
		roll_timer = roll_time
		velocity.x = (1 if facing_right else -1) * roll_speed
		sprite.play("roll")

	# slide
	if Input.is_action_pressed("slide") and is_on_floor():
		if not is_sliding:
			is_sliding = true
			sprite.play("slide")
		velocity.x = (1 if facing_right else -1) * slide_speed
	else:
		if is_sliding:
			is_sliding = false

	# attack combo
	if Input.is_action_just_pressed("attack") and not is_dashing and not is_rolling:
		if not is_attacking:
			is_attacking = true
			attack_combo = 1
			velocity.x = 0
			sprite.play("attack1")
		elif is_attacking and attack_combo == 1 and sprite.animation == "attack1":
			attack_combo = 2

	# timers
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0:
			is_rolling = false

# ===== wall slide =====
func _check_wall_slide() -> void:
	is_wall_sliding = false
	if not is_on_floor() and is_on_wall() and velocity.y > 0:
		is_wall_sliding = true
		if velocity.y > wall_slide_speed:
			velocity.y = wall_slide_speed

		var wall_normal = get_wall_normal()
		if wall_normal.x > 0: # wall on left
			facing_right = true
		elif wall_normal.x < 0: # wall on right
			facing_right = false
		sprite.flip_h = (not facing_right) if sprite_faces_right else facing_right

# ===== wall jump =====
func _wall_jump() -> void:
	if is_on_wall():
		var wall_normal = get_wall_normal()
		velocity.y = wall_jump_velocity.y
		velocity.x = wall_jump_velocity.x * -wall_normal.x
		if abs(velocity.x) < 1:
			velocity.x = wall_jump_velocity.x * -wall_normal.x
		is_wall_sliding = false
		sprite.play("wall_jump")

# ===== animation update =====
func _update_animation() -> void:
	if is_attacking or is_dashing or is_rolling or is_sliding:
		if is_sliding and sprite.animation != "slide":
			sprite.play("slide")
		return

	if is_wall_sliding:
		sprite.play("wall_slide")
		return

	if not is_on_floor():
		if velocity.y < 0:
			sprite.play("jump")
		else:
			sprite.play("fall")
		return

	if abs(velocity.x) < 1:
		sprite.play("idle")
	else:
		sprite.play("run")

# ===== animation finished =====
func _on_animation_finished(anim_name: String = "") -> void:
	match sprite.animation:
		"attack1":
			if attack_combo == 2:
				sprite.play("attack2")
			else:
				is_attacking = false
				attack_combo = 0
		"attack2":
			is_attacking = false
			attack_combo = 0
		"roll":
			is_rolling = false
		"dash":
			is_dashing = false
		"slide":
			is_sliding = false


func _on_hitbox_body_entered(body: Node2D) -> void:
	get_tree().change_scene_to_file("res://player.tscn")
