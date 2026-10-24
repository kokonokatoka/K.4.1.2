extends CharacterBody3D

# ==============================================================================
# TACTICAL MODULAR DROID "AEGIS-04" - Controller & Procedural Mecha System
# ==============================================================================

# --- 移動・物理パラメータ ---
const SPEED_NORMAL: float = 5.5       # ノーマル足（二足歩行）の速度
const SPEED_FAST: float = 13.5        # 高速足（ホバースラスター）の速度
const ACCEL: float = 14.0             # 加速度
const FRICTION: float = 16.0          # 減速度
const JUMP_VELOCITY: float = 7.5      # ジャンプ力
const GRAVITY: float = 20.0           # 重力

# --- パーツの状態フラグ ---
var has_eyes: bool = true             # true: 目パーツ装備 / false: 取り外し(視界喪失)
var is_fast_legs: bool = false        # false: ノーマル二足 / true: 高速ホバー足

# --- アニメーション・演出用変数 ---
var anim_time: float = 0.0
var current_blind_amount: float = 0.0
var target_blind_amount: float = 0.0

# --- シーンツリー上の基本ノード参照 ---
@onready var visuals: Node3D = $Visuals
@onready var body_node: MeshInstance3D = $Visuals/Body
@onready var head_eyes: MeshInstance3D = $Visuals/HeadEyes
@onready var legs_node: MeshInstance3D = $Visuals/Legs
@onready var blind_overlay: ColorRect = $CanvasLayer/BlindOverlay
@onready var status_label: RichTextLabel = $CanvasLayer/HUDRoot/TopLeftPanel/Margin/StatusLabel
@onready var warning_banner: PanelContainer = $CanvasLayer/HUDRoot/WarningBanner
@onready var telemetry_label: Label = $CanvasLayer/HUDRoot/BottomBar/TelemetryLabel

# --- プロシージャル生成する可動メカ部位の参照 ---
var left_leg_pivot: Node3D
var right_leg_pivot: Node3D
var hover_unit_root: Node3D
var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var thruster_flames: Array[MeshInstance3D] = []
var neck_warning_light: OmniLight3D
var neck_spark_mesh: MeshInstance3D
var main_camera: Camera3D

# --- マテリアル定義 ---
var mat_armor_white := StandardMaterial3D.new()
var mat_armor_dark := StandardMaterial3D.new()
var mat_joint_metal := StandardMaterial3D.new()
var mat_cyan_glow := StandardMaterial3D.new()
var mat_crimson_armor := StandardMaterial3D.new()
var mat_thruster_flame := StandardMaterial3D.new()
var mat_warning_red := StandardMaterial3D.new()

func _ready() -> void:
	_init_materials()
	_build_detailed_mecha_parts()
	main_camera = get_viewport().get_camera_3d()
	_update_parts_state(true)

func _init_materials() -> void:
	# チタンホワイト装甲
	mat_armor_white.albedo_color = Color(0.85, 0.88, 0.92)
	mat_armor_white.metallic = 0.45
	mat_armor_white.roughness = 0.25

	# ダークカーボン装甲
	mat_armor_dark.albedo_color = Color(0.14, 0.16, 0.20)
	mat_armor_dark.metallic = 0.75
	mat_armor_dark.roughness = 0.32

	# 関節ガンメタル
	mat_joint_metal.albedo_color = Color(0.25, 0.28, 0.32)
	mat_joint_metal.metallic = 0.85
	mat_joint_metal.roughness = 0.4

	# 高輝度シアン発光（バイザー・コア）
	mat_cyan_glow.albedo_color = Color(0.1, 0.95, 1.0)
	mat_cyan_glow.emission_enabled = true
	mat_cyan_glow.emission = Color(0.0, 0.85, 1.0)
	mat_cyan_glow.emission_energy_multiplier = 3.0

	# 高速ホバー脚用クリムゾンレッド装甲
	mat_crimson_armor.albedo_color = Color(0.88, 0.15, 0.22)
	mat_crimson_armor.metallic = 0.65
	mat_crimson_armor.roughness = 0.22

	# スラスタージェット炎（オレンジ〜アンバー発光）
	mat_thruster_flame.albedo_color = Color(1.0, 0.65, 0.1)
	mat_thruster_flame.emission_enabled = true
	mat_thruster_flame.emission = Color(1.0, 0.45, 0.0)
	mat_thruster_flame.emission_energy_multiplier = 4.0

	# 目パーツ喪失時の緊急赤色灯
	mat_warning_red.albedo_color = Color(1.0, 0.1, 0.1)
	mat_warning_red.emission_enabled = true
	mat_warning_red.emission = Color(1.0, 0.05, 0.05)
	mat_warning_red.emission_energy_multiplier = 3.5

# --- プリミティブを組み合わせてAAA風ハイディテールSFメカを構築 ---
func _build_detailed_mecha_parts() -> void:
	# 1. Body（胸部・コア・肩アーマー・腕・バックパック）のディテール化
	body_node.material_override = mat_armor_dark
	
	# 胸部フロントプレート
	var chest_plate := _add_box(body_node, Vector3(0.72, 0.55, 0.18), Vector3(0, 0.08, -0.26), mat_armor_white)
	# 胸部アークコア（発光）
	var _core := _add_box(chest_plate, Vector3(0.26, 0.18, 0.08), Vector3(0, 0.04, -0.08), mat_cyan_glow)
	
	# バックパック＆デュアルブースター
	var backpack := _add_box(body_node, Vector3(0.58, 0.52, 0.28), Vector3(0, 0.08, 0.34), mat_armor_dark)
	for side in [-1.0, 1.0]:
		var nozzle := _add_box(backpack, Vector3(0.16, 0.22, 0.22), Vector3(side * 0.2, -0.1, 0.14), mat_joint_metal)
		nozzle.rotation_degrees.x = 20.0
		var flame := _add_box(nozzle, Vector3(0.12, 0.12, 0.45), Vector3(0, 0, 0.28), mat_thruster_flame)
		thruster_flames.append(flame)

	# 左右の肩＆可動アームユニット
	left_arm_pivot = Node3D.new()
	left_arm_pivot.position = Vector3(-0.52, 0.25, 0)
	body_node.add_child(left_arm_pivot)
	_build_arm_mesh(left_arm_pivot, -1.0)

	right_arm_pivot = Node3D.new()
	right_arm_pivot.position = Vector3(0.52, 0.25, 0)
	body_node.add_child(right_arm_pivot)
	_build_arm_mesh(right_arm_pivot, 1.0)

	# 目パーツ取り外し時に露出する首元エマージェンシーソケット
	neck_spark_mesh = _add_box(body_node, Vector3(0.24, 0.14, 0.24), Vector3(0, 0.48, 0), mat_warning_red)
	neck_warning_light = OmniLight3D.new()
	neck_warning_light.light_color = Color(1.0, 0.15, 0.15)
	neck_warning_light.light_energy = 2.0
	neck_warning_light.omni_range = 4.5
	neck_spark_mesh.add_child(neck_warning_light)

	# 2. HeadEyes（頭部・光学センサー・サーチライト）のディテール化
	head_eyes.material_override = mat_armor_white
	# 発光バイザーアイ
	var _visor := _add_box(head_eyes, Vector3(0.54, 0.16, 0.12), Vector3(0, 0.0, -0.22), mat_cyan_glow)
	# 頭部センサーブレード（左右のアンテナ）
	var _ant_l := _add_box(head_eyes, Vector3(0.06, 0.38, 0.22), Vector3(-0.30, 0.16, 0.05), mat_armor_dark)
	var _ant_r := _add_box(head_eyes, Vector3(0.06, 0.38, 0.22), Vector3(0.30, 0.16, 0.05), mat_armor_dark)
	
	# 前方を照らすタクティカル・サーチライト
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 0, -0.3)
	spot.light_color = Color(0.75, 0.95, 1.0)
	spot.light_energy = 4.5
	spot.spot_range = 16.0
	spot.spot_angle = 38.0
	spot.shadow_enabled = true
	head_eyes.add_child(spot)

	# 3. Legs（ノーマル二足歩行脚 ＆ 高速ホバースラスター脚）のディテール化
	# 親の箱メッシュ自体は透明な腰ジョイントにし、子ノードに二足とホバー脚を構築
	legs_node.material_override = mat_joint_metal
	
	# (A) ノーマル二足歩行ユニット
	left_leg_pivot = Node3D.new()
	left_leg_pivot.position = Vector3(-0.22, 0.2, 0)
	legs_node.add_child(left_leg_pivot)
	_build_biped_leg(left_leg_pivot)

	right_leg_pivot = Node3D.new()
	right_leg_pivot.position = Vector3(0.22, 0.2, 0)
	legs_node.add_child(right_leg_pivot)
	_build_biped_leg(right_leg_pivot)

	# (B) 高速ホバー・スラスターユニット
	hover_unit_root = Node3D.new()
	hover_unit_root.position = Vector3(0, 0.1, 0)
	legs_node.add_child(hover_unit_root)
	_build_hover_legs(hover_unit_root)

func _build_arm_mesh(pivot: Node3D, side: float) -> void:
	# ショルダーアーマー
	var shoulder := _add_box(pivot, Vector3(0.28, 0.26, 0.42), Vector3(side * 0.08, 0.06, 0), mat_armor_white)
	shoulder.rotation_degrees.z = side * -12.0
	# 上腕・前腕
	var _upper := _add_box(pivot, Vector3(0.16, 0.36, 0.18), Vector3(side * 0.06, -0.20, 0), mat_joint_metal)
	var forearm := _add_box(pivot, Vector3(0.20, 0.38, 0.26), Vector3(side * 0.08, -0.48, -0.06), mat_armor_dark)
	# 腕のエネルギーライン
	var _blade := _add_box(forearm, Vector3(0.05, 0.28, 0.06), Vector3(side * 0.09, 0, -0.10), mat_cyan_glow)

func _build_biped_leg(pivot: Node3D) -> void:
	# 太腿
	var _thigh := _add_box(pivot, Vector3(0.22, 0.32, 0.24), Vector3(0, -0.15, 0), mat_armor_white)
	# 膝アーマー
	var _knee := _add_box(pivot, Vector3(0.24, 0.16, 0.28), Vector3(0, -0.28, -0.04), mat_cyan_glow)
	# 脛（すね）
	var _shin := _add_box(pivot, Vector3(0.20, 0.32, 0.26), Vector3(0, -0.42, 0.02), mat_armor_dark)
	# フットパッド
	var _foot := _add_box(pivot, Vector3(0.26, 0.12, 0.42), Vector3(0, -0.54, -0.05), mat_armor_white)

func _build_hover_legs(root: Node3D) -> void:
	for side in [-1.0, 1.0]:
		# 流線型ホバーポッド
		var pod := _add_box(root, Vector3(0.32, 0.28, 0.78), Vector3(side * 0.28, -0.22, 0.05), mat_crimson_armor)
		pod.rotation_degrees.x = -8.0
		# サイドウイングフィン
		var fin := _add_box(pod, Vector3(0.24, 0.06, 0.45), Vector3(side * 0.22, 0.05, 0.08), mat_armor_white)
		fin.rotation_degrees.z = side * -20.0
		# 底面ホバーリング発光
		var _ring := _add_box(pod, Vector3(0.24, 0.06, 0.62), Vector3(0, -0.15, 0), mat_thruster_flame)
		# 後方ジェット噴射炎
		var flame := _add_box(pod, Vector3(0.18, 0.14, 0.55), Vector3(0, 0, 0.52), mat_thruster_flame)
		thruster_flames.append(flame)

func _add_box(parent: Node3D, box_size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

# ==============================================================================
# 入力処理（1キー：目パーツ切替 / 2キー：足パーツ切替 / Space：ジャンプ）
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			# 1キー：目パーツの「装備 / 取り外し」切り替え
			has_eyes = not has_eyes
			_update_parts_state(false)
		elif event.keycode == KEY_2:
			# 2キー：足パーツの「ノーマル足 / 高速足」切り替え
			is_fast_legs = not is_fast_legs
			_update_parts_state(false)

# ==============================================================================
# 毎フレームの移動・アニメーション・カメラ・シェーダー更新
# ==============================================================================
func _physics_process(delta: float) -> void:
	# 1. 重力とジャンプ処理
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = JUMP_VELOCITY

	# 2. WASD / 矢印キーによる平面移動入力（Input Map設定不要）
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

	# 3. 現在の足パーツに応じた目標速度と加減速
	var max_speed: float = SPEED_FAST if is_fast_legs else SPEED_NORMAL
	if input_dir != Vector2.ZERO:
		velocity.x = move_toward(velocity.x, input_dir.x * max_speed, ACCEL * max_speed * delta)
		velocity.z = move_toward(velocity.z, input_dir.y * max_speed, ACCEL * max_speed * delta)
		# 進行方向へスムーズに機体を回転
		var target_angle := atan2(-input_dir.x, -input_dir.y)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta * 3.0)

	move_and_slide()

	# 4. プロシージャル・メカアニメーション（歩行 / ホバー / ブースト炎）
	_animate_mecha(delta, input_dir)

	# 5. 見下ろしカメラのスムーズ追従 ＆ ダイナミックFOV
	_update_camera(delta)

	# 6. 光学センサー（暗闇シェーダー）とテレメトリーUIの更新
	_update_visor_and_telemetry(delta)

func _animate_mecha(delta: float, input_dir: Vector2) -> void:
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := horiz_speed > 0.2
	anim_time += delta * (horiz_speed * 1.8 if is_moving else 2.0)

	if is_fast_legs:
		# 【高速ホバー足モード】浮遊＋前傾エアロフォーム＋ジェット炎噴射
		var hover_bob := 0.16 + sin(Time.get_ticks_msec() * 0.008) * 0.05
		visuals.position.y = lerp(visuals.position.y, hover_bob, 10.0 * delta)
		# 移動時は鋭く前傾姿勢になる
		var target_pitch := -0.28 if is_moving else -0.05
		visuals.rotation.x = lerp(visuals.rotation.x, target_pitch, 10.0 * delta)
		# 腕を後方へ流す
		left_arm_pivot.rotation.x = lerp(left_arm_pivot.rotation.x, -0.55 if is_moving else -0.1, 10.0 * delta)
		right_arm_pivot.rotation.x = lerp(right_arm_pivot.rotation.x, -0.55 if is_moving else -0.1, 10.0 * delta)
	else:
		# 【ノーマル二足歩行モード】交互の脚踏み出し＋上下バウンス＋腕振り
		if is_moving:
			var stride := sin(anim_time) * 0.65
			left_leg_pivot.rotation.x = stride
			right_leg_pivot.rotation.x = -stride
			left_arm_pivot.rotation.x = -stride * 0.7
			right_arm_pivot.rotation.x = stride * 0.7
			visuals.position.y = abs(cos(anim_time)) * 0.08
			visuals.rotation.x = lerp(visuals.rotation.x, -0.08, 10.0 * delta)
		else:
			left_leg_pivot.rotation.x = lerp(left_leg_pivot.rotation.x, 0.0, 12.0 * delta)
			right_leg_pivot.rotation.x = lerp(right_leg_pivot.rotation.x, 0.0, 12.0 * delta)
			left_arm_pivot.rotation.x = lerp(left_arm_pivot.rotation.x, 0.0, 12.0 * delta)
			right_arm_pivot.rotation.x = lerp(right_arm_pivot.rotation.x, 0.0, 12.0 * delta)
			visuals.position.y = lerp(visuals.position.y, sin(Time.get_ticks_msec() * 0.004) * 0.02, 10.0 * delta)
			visuals.rotation.x = lerp(visuals.rotation.x, 0.0, 10.0 * delta)

	# スラスター炎の伸縮（高速足で移動中に激しく噴射）
	var flame_scale_z := 0.01
	if is_fast_legs:
		flame_scale_z = (1.2 + sin(Time.get_ticks_msec() * 0.04) * 0.35) if is_moving else 0.35
	elif is_moving:
		flame_scale_z = 0.25

	for flame in thruster_flames:
		flame.visible = flame_scale_z > 0.05
		flame.scale.z = flame_scale_z

	# 目パーツ取り外し時の緊急ビーコン点滅
	if not has_eyes and neck_warning_light:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.015)
		neck_warning_light.light_energy = 0.5 + pulse * 3.0

func _update_camera(delta: float) -> void:
	if not is_instance_valid(main_camera):
		return
	# プレイヤーの位置＋進行方向の少し先を見下ろすスムーズカメラ
	var look_ahead := Vector3(velocity.x, 0, velocity.z) * 0.22
	var target_cam_pos := global_position + look_ahead + Vector3(0, 11.5, 8.5)
	main_camera.global_position = main_camera.global_position.lerp(target_cam_pos, 6.5 * delta)
	
	# 高速移動時は視野角（FOV）を少し広げてスピード感を強調
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	var target_fov := 56.0 + (horiz_speed / SPEED_FAST) * 10.0
	main_camera.fov = lerp(main_camera.fov, target_fov, 5.0 * delta)

func _update_visor_and_telemetry(delta: float) -> void:
	# 光学センサーシェーダーのブラインド量をスムーズに補間
	current_blind_amount = lerp(current_blind_amount, target_blind_amount, 8.0 * delta)
	if blind_overlay and blind_overlay.material is ShaderMaterial:
		var sm: ShaderMaterial = blind_overlay.material
		sm.set_shader_parameter("blind_amount", current_blind_amount)
		if is_instance_valid(main_camera):
			var screen_pos := main_camera.unproject_position(global_position + Vector3(0, 1.0, 0))
			var vp_size := get_viewport().get_visible_rect().size
			if vp_size.x > 0 and vp_size.y > 0:
				sm.set_shader_parameter("player_screen_pos", screen_pos / vp_size)

	# 下部テレメトリーバーのリアルタイム速度表示
	if telemetry_label:
		var spd := Vector2(velocity.x, velocity.z).length()
		telemetry_label.text = "UNIT: AEGIS-04  |  VELOCITY: %05.2f m/s  |  POS: (%+.1f, %+.1f)  |  [WASD] MOVE   [SPACE] JUMP   [1] EYES   [2] LEGS" % [
			spd, global_position.x, global_position.z
		]

# ==============================================================================
# パーツ換装時の状態・UI更新
# ==============================================================================
func _update_parts_state(immediate: bool = false) -> void:
	# 1. 目パーツ（Head / Optical Sensor Unit）
	if head_eyes:
		head_eyes.visible = has_eyes
	if neck_spark_mesh:
		neck_spark_mesh.visible = not has_eyes
	
	target_blind_amount = 0.0 if has_eyes else 1.0
	if immediate:
		current_blind_amount = target_blind_amount

	if warning_banner:
		warning_banner.visible = not has_eyes

	# 2. 足パーツ（ノーマル二足 ⇔ 高速ホバースラスター）
	if left_leg_pivot and right_leg_pivot and hover_unit_root:
		left_leg_pivot.visible = not is_fast_legs
		right_leg_pivot.visible = not is_fast_legs
		hover_unit_root.visible = is_fast_legs

	# 換装時の軽いポップ演出
	if not immediate and visuals:
		var tw := create_tween()
		tw.tween_property(visuals, "scale", Vector3(1.15, 0.88, 1.15), 0.07)
		tw.tween_property(visuals, "scale", Vector3.ONE, 0.14)

	# 3. 左上タクティカルHUDのテキスト更新
	if status_label:
		var eye_status := "[color=#00f0ff]● ONLINE (TACTICAL VISOR)[/color]" if has_eyes else "[color=#ff3344]✖ OFFLINE (BLIND / SONAR)[/color]"
		var leg_status := "[color=#ff8800]⚡ HIGH-MOBILITY HOVER (13.5 m/s)[/color]" if is_fast_legs else "[color=#44aaff]■ BIPEDAL HEAVY LEGS (5.5 m/s)[/color]"
		
		status_label.text = (
			"[b][color=#aaccff]AEGIS-04 MODULAR SYSTEM[/color][/b]\n" +
			"[color=#667788]──────────────────────────────[/color]\n" +
			"[b][1] HEAD / EYES :[/b] " + eye_status + "\n" +
			"[b][2] LEG UNIT    :[/b] " + leg_status
		)
