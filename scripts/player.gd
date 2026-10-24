extends CharacterBody2D
class_name Player

@export var is_local: bool = false
@export var speed: float = 300.0

var player_id: String = ""
var player_name: String = "Player"
var player_color: Color = Color(0.2, 0.6, 1.0)

var target_position: Vector2 = Vector2.ZERO
var move_sync_timer: float = 0.0
const SYNC_INTERVAL: float = 0.05 # 20Hzでサーバーに位置送信

@onready var name_label: Label = $NameLabel
@onready var avatar: ColorRect = $Avatar
@onready var effect_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	target_position = position
	update_appearance()

func setup(id: String, p_name: String, p_color: Color, local: bool) -> void:
	player_id = id
	player_name = p_name
	player_color = p_color
	is_local = local
	target_position = position
	update_appearance()

func update_appearance() -> void:
	if name_label:
		name_label.text = player_name
	if avatar:
		avatar.color = player_color

func _physics_process(delta: float) -> void:
	if is_local:
		var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = input_vector * speed
		move_and_slide()
		
		# 位置同期タイマー
		move_sync_timer += delta
		if move_sync_timer >= SYNC_INTERVAL:
			move_sync_timer = 0.0
			var network_mgr = get_node_or_null("/root/Main/NetworkManager")
			if network_mgr and network_mgr.has_method("send_movement"):
				network_mgr.send_movement(global_position)
	else:
		# リモートプレイヤーは目標位置に向けて滑らかに補間
		global_position = global_position.lerp(target_position, 15.0 * delta)

func set_remote_position(pos: Vector2) -> void:
	target_position = pos

func play_action_effect(action_type: String) -> void:
	# 簡単なジャンプやパルス効果
	var tween = create_tween()
	tween.tween_property(avatar, "scale", Vector2(1.4, 1.4), 0.1)
	tween.tween_property(avatar, "scale", Vector2(1.0, 1.0), 0.15)
