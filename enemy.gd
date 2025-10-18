extends CharacterBody2D

@export var speed := 50.0
@export var gravity := 900.0
@export var health := 3
@export var damage := 1
@export var detection_range := 150.0
@export var attack_range := 40.0
@export var attack_cooldown := 1.2

var player : Node2D
var direction := -1
var can_attack := true
var is_dead := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox

func _ready():
	sprite.play("walk")
	hitbox.connect("body_entered", Callable(self, "_on_hitbox_body_entered"))

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	velocity.y += gravity * delta

	if player == null:
		_find_player()

	if player and not is_dead:
		_handle_ai(delta)

	move_and_slide()
	_update_animation()

func _find_player():
	var p = get_tree().get_first_node_in_group("Player")
	if p:
		player = p

func _handle_ai(delta):
	var dist = player.global_position.distance_to(global_position)
	var dir = sign(player.global_position.x - global_position.x)

	if dist < detection_range and dist > attack_range:
		direction = dir
		velocity.x = direction * speed
	elif dist <= attack_range and can_attack:
		velocity.x = 0
		_attack()
	else:
		velocity.x = 0

	sprite.flip_h = direction < 0

func _attack():
	can_attack = false
	sprite.play("attack")
	$Timer.start(attack_cooldown)

func _on_hitbox_body_entered(body):
	if body.is_in_group("Player") and not is_dead:
		if body.has_method("take_damage"):
			body.take_damage(damage)

func _on_Timer_timeout():
	can_attack = true

func take_damage(amount: int):
	if is_dead:
		return
	health -= amount
	sprite.play("hurt")
	if health <= 0:
		_die()

func _die():
	is_dead = true
	sprite.play("death")
	set_collision_layer(0)
	set_collision_mask(0)
	queue_free()

func _update_animation():
	if is_dead:
		return
	if sprite.animation in ["attack", "hurt"]:
		return
	if abs(velocity.x) > 1:
		sprite.play("walk")
	else:
		sprite.play("idle")
