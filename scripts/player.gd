extends CharacterBody3D

# --- 移動スピード設定 ---
const SPEED_NORMAL: float = 5.0   # ノーマル足の速度
const SPEED_FAST: float = 12.0    # 高速足の速度
const GRAVITY: float = 20.0       # 重力

# --- パーツの状態フラグ ---
var has_eyes: bool = true         # 目パーツがあるか（true: あり, false: なし）
var is_fast_legs: bool = false    # 足パーツの種類（false: ノーマル足, true: 高速足）

# --- ノード参照 ---
@onready var visuals: Node3D = $Visuals
@onready var head_eyes: MeshInstance3D = $Visuals/HeadEyes
@onready var legs: MeshInstance3D = $Visuals/Legs
@onready var blind_overlay: ColorRect = $CanvasLayer/BlindOverlay
@onready var status_label: Label = $CanvasLayer/StatusLabel

# 足パーツの色分け用マテリアル
var mat_legs_normal := StandardMaterial3D.new()
var mat_legs_fast := StandardMaterial3D.new()

func _ready() -> void:
	# 足パーツの色設定（ノーマル＝青、高速＝赤）
	mat_legs_normal.albedo_color = Color(0.2, 0.5, 0.9)
	mat_legs_fast.albedo_color = Color(1.0, 0.2, 0.2)
	
	# 初期状態を反映
	_update_parts_state()

func _unhandled_input(event: InputEvent) -> void:
	# キーが押された瞬間だけ判定（押しっぱなしの連続発火を防止）
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			# 1キー：目パーツの「装備 / 取り外し」切り替え
			has_eyes = not has_eyes
			_update_parts_state()
		elif event.keycode == KEY_2:
			# 2キー：足パーツの「ノーマル足 / 高速足」切り替え
			is_fast_legs = not is_fast_legs
			_update_parts_state()

func _physics_process(delta: float) -> void:
	# 1. 重力処理
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# 2. WASDキーによる平面移動入力（Input Map未設定でもそのまま動く方式）
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	input_dir = input_dir.normalized()

	# 3. 現在の足パーツに応じた速度を選択
	var current_speed: float = SPEED_FAST if is_fast_legs else SPEED_NORMAL

	# 4. 移動ベクトルの適用（3DのXZ平面）
	if input_dir != Vector2.ZERO:
		velocity.x = input_dir.x * current_speed
		velocity.z = input_dir.y * current_speed
		# 進行方向にロボットの見た目を回転させる
		var target_angle := atan2(-input_dir.x, -input_dir.y)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 15.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()

# --- パーツ切り替え時の見た目・効果更新 ---
func _update_parts_state() -> void:
	# 【目パーツ】モデルの表示/非表示 ＆ 暗闇フィルターのON/OFF
	if head_eyes:
		head_eyes.visible = has_eyes
	if blind_overlay:
		blind_overlay.visible = not has_eyes

	# 【足パーツ】モデルの色とスケール変化
	if legs:
		legs.material_override = mat_legs_fast if is_fast_legs else mat_legs_normal
		legs.scale = Vector3(1.2, 1.0, 1.2) if is_fast_legs else Vector3(1.0, 1.0, 1.0)

	# 【UI表示】現在のパーツ状態を画面左上に表示
	if status_label:
		var eyes_text := "装備中 (視界正常)" if has_eyes else "なし (視界制限・暗闇)"
		var legs_text := "高速足 (Speed: %.0f)" % SPEED_FAST if is_fast_legs else "ノーマル足 (Speed: %.0f)" % SPEED_NORMAL
		status_label.text = "【操作】[WASD] 移動  [1] 目パーツ切替  [2] 足パーツ切替\n" \
			+ "・目パーツ (Head/Eyes): " + eyes_text + "\n" \
			+ "・足パーツ (Legs): " + legs_text
