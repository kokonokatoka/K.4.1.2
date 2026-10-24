extends CharacterBody3D

# ==============================================================================
# AAA-STYLE MODULAR MECHA SYSTEM "AEGIS-CUSTOM"
# Full Assembly (Head/Eyes, Ears, Armor, Arms, 4 Leg Types, R/L/Back Weapons),
# Real-time Scale Sliders, Combat Projectiles, and Interactive Garage UI
# ==============================================================================

# --- パーツ選択肢の定義 ---
const EYE_NAMES := ["STRIKER VISOR", "MONO-EYE SNIPER", "QUAD NIGHT-OPS", "NONE (BLIND SONAR)"]
const EAR_NAMES := ["V-FIN BLADES", "VALKYRIE WINGS", "ONI HORNS & RADAR", "NONE"]
const ARMOR_NAMES := ["LIGHT FRAME", "MEDIUM TACTICAL", "HEAVY JUGGERNAUT"]
const LEG_NAMES := ["BIPEDAL STANDARD", "HOVER THRUSTERS", "REVERSE-JOINT", "SPIDER QUAD-LEGS"]
const R_WPN_NAMES := ["PLASMA RIFLE", "HEAVY GATLING", "HYPER RAILGUN"]
const L_WPN_NAMES := ["LASER BLADE", "HEAVY BAZOOKA", "AEGIS SHIELD"]
const BACK_WPN_NAMES := ["MISSILE PODS", "TWIN CANNONS", "SERAPHIM WINGS"]
const THEME_NAMES := ["AEGIS WHITE", "CRIMSON NIGHT", "TITAN GOLD", "EVA VIOLET", "MILITARY OLIVE"]

# --- 現在のアセンブル状態 ---
var eye_mode: int = 0          # 0..2: 装備中, 3: 取り外し(暗闇ソナー)
var ear_type: int = 0          # 0..3: 耳・アンテナ種類
var armor_type: int = 1        # 0: 軽量, 1: 標準, 2: 重装
var leg_type: int = 0          # 0: 二足, 1: ホバー, 2: 逆関節, 3: 4脚スパイダー
var r_wpn_type: int = 0        # 0: ライフル, 1: ガトリング, 2: レールガン
var l_wpn_type: int = 0        # 0: ブレード, 1: バズーカ, 2: シールド
var back_wpn_type: int = 0     # 0: ミサイル, 1: キャノン, 2: セラフィムウイング
var color_theme: int = 0       # 0..4: カラープリセット

# --- プロポーション（大きさ）スライダー値 ---
var scale_overall: float = 1.0
var scale_arms: float = 1.0
var scale_legs: float = 1.0
var scale_armor: float = 1.0

# --- カメラ・UI状態 ---
var garage_cam_mode: bool = false
var garage_orbit_angle: float = 0.4
var anim_time: float = 0.0
var current_blind_amount: float = 0.0
var target_blind_amount: float = 0.0

# --- 戦闘・クールダウン管理 ---
var r_fire_cd: float = 0.0
var l_fire_cd: float = 0.0
var back_fire_cd: float = 0.0
var blade_slash_timer: float = 0.0
var projectiles: Array[Dictionary] = []

# --- シーンノード参照 ---
@onready var visuals: Node3D = $Visuals
@onready var body_node: MeshInstance3D = $Visuals/Body
@onready var head_eyes: MeshInstance3D = $Visuals/HeadEyes
@onready var legs_node: MeshInstance3D = $Visuals/Legs
@onready var blind_overlay: ColorRect = $CanvasLayer/BlindOverlay
@onready var hud_root: Control = $CanvasLayer/HUDRoot
@onready var status_label: RichTextLabel = $CanvasLayer/HUDRoot/TopLeftPanel/Margin/StatusLabel
@onready var warning_banner: PanelContainer = $CanvasLayer/HUDRoot/WarningBanner
@onready var telemetry_label: Label = $CanvasLayer/HUDRoot/BottomBar/TelemetryLabel

# --- 動的に構築するメカ部位ノード参照 ---
var mecha_root: Node3D
var torso_pivot: Node3D
var head_pivot: Node3D
var ears_root: Node3D
var eye_models: Array[Node3D] = []
var ear_models: Array[Node3D] = []
var armor_models: Array[Node3D] = []

var left_arm_pivot: Node3D
var right_arm_pivot: Node3D
var left_forearm_pivot: Node3D
var right_forearm_pivot: Node3D
var r_wpn_models: Array[Node3D] = []
var l_wpn_models: Array[Node3D] = []
var back_wpn_models: Array[Node3D] = []
var r_muzzle_marker: Marker3D
var l_muzzle_marker: Marker3D
var blade_effect_mesh: MeshInstance3D

var leg_type_roots: Array[Node3D] = []
var biped_l_piv: Node3D
var biped_r_piv: Node3D
var rev_l_piv: Node3D
var rev_r_piv: Node3D
var quad_leg_pivs: Array[Node3D] = []

var thruster_flames: Array[MeshInstance3D] = []
var head_spot_light: SpotLight3D
var neck_warning_light: OmniLight3D
var neck_spark_mesh: MeshInstance3D
var main_camera: Camera3D
var arena_main: Node3D

# --- カスタムUIラベル参照 ---
var ui_value_labels: Dictionary = {}
var garage_panel: PanelContainer

# --- PBRマテリアル群 ---
var mat_primary := StandardMaterial3D.new()
var mat_secondary := StandardMaterial3D.new()
var mat_frame := StandardMaterial3D.new()
var mat_chrome := StandardMaterial3D.new()
var mat_glow := StandardMaterial3D.new()
var mat_sub_glow := StandardMaterial3D.new()
var mat_flame := StandardMaterial3D.new()
var mat_blade := StandardMaterial3D.new()
var mat_shield := StandardMaterial3D.new()
var mat_warning := StandardMaterial3D.new()

func _ready() -> void:
	arena_main = get_parent()
	main_camera = get_viewport().get_camera_3d()
	
	# シーン内のプレースホルダーメッシュを非表示にし、精密プロシージャルモデルを構築
	body_node.mesh = null
	head_eyes.mesh = null
	legs_node.mesh = null

	_init_materials()
	_build_complete_mecha()
	_build_garage_custom_ui()
	_apply_color_theme()
	_refresh_assembly_state(true)

func _init_materials() -> void:
	mat_primary.metallic = 0.55
	mat_primary.roughness = 0.24

	mat_secondary.metallic = 0.72
	mat_secondary.roughness = 0.30

	mat_frame.albedo_color = Color(0.18, 0.20, 0.24)
	mat_frame.metallic = 0.85
	mat_frame.roughness = 0.38

	mat_chrome.albedo_color = Color(0.75, 0.80, 0.86)
	mat_chrome.metallic = 0.95
	mat_chrome.roughness = 0.15

	mat_glow.emission_enabled = true
	mat_glow.emission_energy_multiplier = 3.2

	mat_sub_glow.emission_enabled = true
	mat_sub_glow.emission_energy_multiplier = 2.5

	mat_flame.albedo_color = Color(1.0, 0.65, 0.15)
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.45, 0.05)
	mat_flame.emission_energy_multiplier = 4.2

	mat_blade.albedo_color = Color(0.2, 1.0, 0.95, 0.85)
	mat_blade.emission_enabled = true
	mat_blade.emission = Color(0.0, 0.95, 1.0)
	mat_blade.emission_energy_multiplier = 4.5
	mat_blade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	mat_shield.albedo_color = Color(0.05, 0.75, 1.0, 0.42)
	mat_shield.emission_enabled = true
	mat_shield.emission = Color(0.0, 0.65, 1.0)
	mat_shield.emission_energy_multiplier = 2.2
	mat_shield.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	mat_warning.albedo_color = Color(1.0, 0.1, 0.1)
	mat_warning.emission_enabled = true
	mat_warning.emission = Color(1.0, 0.05, 0.05)
	mat_warning.emission_energy_multiplier = 3.8

func _apply_color_theme() -> void:
	match color_theme:
		0: # AEGIS WHITE
			mat_primary.albedo_color = Color(0.86, 0.89, 0.94)
			mat_secondary.albedo_color = Color(0.14, 0.18, 0.25)
			mat_glow.albedo_color = Color(0.1, 0.95, 1.0)
			mat_glow.emission = Color(0.0, 0.82, 1.0)
			mat_sub_glow.albedo_color = Color(1.0, 0.55, 0.1)
			mat_sub_glow.emission = Color(1.0, 0.45, 0.0)
		1: # CRIMSON NIGHT
			mat_primary.albedo_color = Color(0.12, 0.12, 0.15)
			mat_secondary.albedo_color = Color(0.75, 0.10, 0.16)
			mat_glow.albedo_color = Color(1.0, 0.15, 0.25)
			mat_glow.emission = Color(1.0, 0.05, 0.15)
			mat_sub_glow.albedo_color = Color(1.0, 0.7, 0.1)
			mat_sub_glow.emission = Color(1.0, 0.6, 0.0)
		2: # TITAN GOLD
			mat_primary.albedo_color = Color(0.85, 0.68, 0.24)
			mat_secondary.albedo_color = Color(0.18, 0.16, 0.14)
			mat_glow.albedo_color = Color(0.2, 0.95, 1.0)
			mat_glow.emission = Color(0.1, 0.85, 1.0)
			mat_sub_glow.albedo_color = Color(1.0, 0.35, 0.1)
			mat_sub_glow.emission = Color(1.0, 0.25, 0.0)
		3: # EVA VIOLET
			mat_primary.albedo_color = Color(0.36, 0.16, 0.58)
			mat_secondary.albedo_color = Color(0.12, 0.14, 0.18)
			mat_glow.albedo_color = Color(0.3, 1.0, 0.2)
			mat_glow.emission = Color(0.2, 0.95, 0.1)
			mat_sub_glow.albedo_color = Color(1.0, 0.55, 0.0)
			mat_sub_glow.emission = Color(1.0, 0.5, 0.0)
		4: # MILITARY OLIVE
			mat_primary.albedo_color = Color(0.32, 0.38, 0.26)
			mat_secondary.albedo_color = Color(0.18, 0.20, 0.16)
			mat_glow.albedo_color = Color(1.0, 0.65, 0.1)
			mat_glow.emission = Color(1.0, 0.55, 0.0)
			mat_sub_glow.albedo_color = Color(0.2, 0.9, 0.5)
			mat_sub_glow.emission = Color(0.1, 0.8, 0.4)

# ==============================================================================
# 精密3Dプロシージャル・メカ造形（全パーツ・武装・脚部・耳・装甲）
# ==============================================================================
func _build_complete_mecha() -> void:
	mecha_root = Node3D.new()
	mecha_root.name = "MechaRoot"
	visuals.add_child(mecha_root)

	# 1. 腰・コアフレーム & トルソー
	torso_pivot = Node3D.new()
	torso_pivot.position = Vector3(0, 1.15, 0)
	mecha_root.add_child(torso_pivot)

	# 腹部油圧シリンダー＆脊椎フレーム
	_add_cyl(torso_pivot, 0.22, 0.26, 0.45, Vector3(0, -0.22, 0), Vector3.ZERO, mat_frame)
	_add_cyl(torso_pivot, 0.06, 0.06, 0.38, Vector3(-0.16, -0.20, -0.10), Vector3(0, 0, -8), mat_chrome)
	_add_cyl(torso_pivot, 0.06, 0.06, 0.38, Vector3(0.16, -0.20, -0.10), Vector3(0, 0, 8), mat_chrome)

	# 胸部メインブロック（傾斜プリズム装甲＋アークリアクターコア）
	_add_box(torso_pivot, Vector3(0.76, 0.56, 0.52), Vector3(0, 0.14, 0), Vector3.ZERO, mat_secondary)
	_add_prism(torso_pivot, Vector3(0.72, 0.46, 0.28), Vector3(0, 0.15, -0.32), Vector3(-90, 0, 0), mat_primary)
	# 胸部中央の円形アークコア
	_add_cyl(torso_pivot, 0.16, 0.16, 0.12, Vector3(0, 0.16, -0.42), Vector3(90, 0, 0), mat_chrome)
	_add_sphere(torso_pivot, 0.12, 0.24, Vector3(0, 0.16, -0.45), mat_glow)

	# 装甲グレード別パーツ（Light / Medium / Heavy）を構築
	_build_armor_variants()

	# 首元の緊急スパーク＆赤色灯（頭部なし時に露出）
	neck_spark_mesh = _add_cyl(torso_pivot, 0.14, 0.18, 0.16, Vector3(0, 0.48, -0.02), Vector3.ZERO, mat_warning)
	neck_warning_light = OmniLight3D.new()
	neck_warning_light.light_color = Color(1.0, 0.15, 0.15)
	neck_warning_light.light_energy = 2.2
	neck_warning_light.omni_range = 5.0
	neck_spark_mesh.add_child(neck_warning_light)

	# 2. 頭部・目センサー & 耳パーツ
	head_pivot = Node3D.new()
	head_pivot.position = Vector3(0, 0.56, -0.04)
	torso_pivot.add_child(head_pivot)
	_build_head_and_ears()

	# 3. 両腕・手（マニピュレーター） & 左右武器
	_build_arms_and_weapons()

	# 4. 背面バックパック & 肩武装 / ウイング
	_build_back_units()

	# 5. 脚部ユニット（4種類：Bipedal / Hover / Reverse-Joint / Spider-Quad）
	_build_all_leg_types()

func _build_armor_variants() -> void:
	armor_models.clear()
	# [0] LIGHT FRAME (軽量高機動フィン)
	var light_grp := Node3D.new()
	torso_pivot.add_child(light_grp)
	_add_box(light_grp, Vector3(0.12, 0.35, 0.45), Vector3(-0.42, 0.22, 0.05), Vector3(0, 0, 18), mat_primary)
	_add_box(light_grp, Vector3(0.12, 0.35, 0.45), Vector3(0.42, 0.22, 0.05), Vector3(0, 0, -18), mat_primary)
	armor_models.append(light_grp)

	# [1] MEDIUM TACTICAL (標準傾斜増加装甲＋フロントスカート)
	var med_grp := Node3D.new()
	torso_pivot.add_child(med_grp)
	_add_box(med_grp, Vector3(0.26, 0.32, 0.48), Vector3(-0.32, 0.16, -0.18), Vector3(0, 12, 0), mat_primary)
	_add_box(med_grp, Vector3(0.26, 0.32, 0.48), Vector3(0.32, 0.16, -0.18), Vector3(0, -12, 0), mat_primary)
	_add_box(med_grp, Vector3(0.28, 0.32, 0.10), Vector3(-0.20, -0.42, -0.28), Vector3(-15, 0, 0), mat_primary)
	_add_box(med_grp, Vector3(0.28, 0.32, 0.10), Vector3(0.20, -0.42, -0.28), Vector3(-15, 0, 0), mat_primary)
	armor_models.append(med_grp)

	# [2] HEAVY JUGGERNAUT (超重装リアクティブアーマー＋大型肩シールド＋重装腰アーマー)
	var hvy_grp := Node3D.new()
	torso_pivot.add_child(hvy_grp)
	_add_box(hvy_grp, Vector3(0.96, 0.52, 0.68), Vector3(0, 0.16, -0.06), Vector3.ZERO, mat_primary)
	_add_box(hvy_grp, Vector3(0.84, 0.24, 0.22), Vector3(0, 0.34, -0.34), Vector3(20, 0, 0), mat_secondary)
	# 左右の重装腰部サイドバインダー
	for s in [-1.0, 1.0]:
		_add_box(hvy_grp, Vector3(0.22, 0.56, 0.66), Vector3(s * 0.48, -0.42, 0), Vector3(0, 0, s * -12), mat_primary)
		_add_box(hvy_grp, Vector3(0.34, 0.44, 0.16), Vector3(s * 0.22, -0.45, -0.34), Vector3(-12, 0, 0), mat_secondary)
	armor_models.append(hvy_grp)

func _build_head_and_ears() -> void:
	eye_models.clear()
	ear_models.clear()

	# 頭部ベースヘルメット（流線型ドーム＋フェイスガード）
	var head_base := Node3D.new()
	head_pivot.add_child(head_base)
	_add_sphere(head_base, 0.26, 0.42, Vector3(0, 0.06, 0.04), mat_primary)
	_add_prism(head_base, Vector3(0.42, 0.28, 0.38), Vector3(0, 0.04, -0.14), Vector3(-90, 0, 0), mat_primary)
	_add_box(head_base, Vector3(0.32, 0.16, 0.26), Vector3(0, -0.06, -0.16), Vector3.ZERO, mat_secondary)

	# サーチライト
	head_spot_light = SpotLight3D.new()
	head_spot_light.position = Vector3(0, 0.05, -0.35)
	head_spot_light.light_color = Color(0.8, 0.95, 1.0)
	head_spot_light.light_energy = 5.0
	head_spot_light.spot_range = 20.0
	head_spot_light.spot_angle = 40.0
	head_spot_light.shadow_enabled = true
	head_pivot.add_child(head_spot_light)

	# Eye Type 0: STRIKER DUAL VISOR
	var eye0 := Node3D.new()
	head_pivot.add_child(eye0)
	_add_box(eye0, Vector3(0.44, 0.11, 0.16), Vector3(0, 0.05, -0.24), Vector3.ZERO, mat_glow)
	eye_models.append(eye0)

	# Eye Type 1: MONO-EYE SNIPER (大型レンズ＋レーザーファインダー)
	var eye1 := Node3D.new()
	head_pivot.add_child(eye1)
	_add_cyl(eye1, 0.14, 0.16, 0.22, Vector3(0, 0.06, -0.26), Vector3(90, 0, 0), mat_chrome)
	_add_sphere(eye1, 0.11, 0.22, Vector3(0, 0.06, -0.35), mat_sub_glow)
	_add_box(eye1, Vector3(0.14, 0.12, 0.36), Vector3(0, 0.24, -0.12), Vector3.ZERO, mat_secondary)
	eye_models.append(eye1)

	# Eye Type 2: QUAD NIGHT-OPS (4眼スパイダーゴーグル)
	var eye2 := Node3D.new()
	head_pivot.add_child(eye2)
	_add_box(eye2, Vector3(0.48, 0.18, 0.20), Vector3(0, 0.06, -0.22), Vector3.ZERO, mat_frame)
	for x_off in [-0.16, -0.06, 0.06, 0.16]:
		_add_cyl(eye2, 0.04, 0.04, 0.12, Vector3(x_off, 0.06, -0.30), Vector3(90, 0, 0), mat_glow)
	eye_models.append(eye2)

	# --- 耳パーツ（EARS / ANTENNA）4種 ---
	ears_root = Node3D.new()
	head_pivot.add_child(ears_root)

	# Ear 0: V-FIN BLADES (V字ブレードアンテナ＋サイドフィン)
	var ear0 := Node3D.new()
	ears_root.add_child(ear0)
	for s in [-1.0, 1.0]:
		_add_box(ear0, Vector3(0.05, 0.48, 0.12), Vector3(s * 0.18, 0.30, -0.20), Vector3(-15, 0, s * -32), mat_glow)
		_add_box(ear0, Vector3(0.06, 0.32, 0.22), Vector3(s * 0.28, 0.12, 0.04), Vector3(-20, 0, s * -15), mat_primary)
	ear_models.append(ear0)

	# Ear 1: VALKYRIE WINGS (大型ウイング耳ユニット)
	var ear1 := Node3D.new()
	ears_root.add_child(ear1)
	for s in [-1.0, 1.0]:
		_add_prism(ear1, Vector3(0.10, 0.68, 0.42), Vector3(s * 0.36, 0.28, 0.12), Vector3(-25, 0, s * -42), mat_primary)
		_add_box(ear1, Vector3(0.04, 0.56, 0.14), Vector3(s * 0.42, 0.32, 0.20), Vector3(-25, 0, s * -42), mat_glow)
	ear_models.append(ear1)

	# Ear 2: ONI HORNS & RADAR (双角ホーン＋電子戦レドーム耳)
	var ear2 := Node3D.new()
	ears_root.add_child(ear2)
	for s in [-1.0, 1.0]:
		_add_cyl(ear2, 0.02, 0.10, 0.55, Vector3(s * 0.22, 0.34, -0.10), Vector3(28, 0, s * -22), mat_sub_glow)
		_add_cyl(ear2, 0.18, 0.18, 0.08, Vector3(s * 0.32, 0.08, 0.02), Vector3(0, 0, 90), mat_secondary)
	ear_models.append(ear2)

	# Ear 3: NONE
	var ear3 := Node3D.new()
	ears_root.add_child(ear3)
	ear_models.append(ear3)

func _build_arms_and_weapons() -> void:
	r_wpn_models.clear()
	l_wpn_models.clear()

	# 左右の肩＆腕ピボット
	left_arm_pivot = Node3D.new()
	left_arm_pivot.position = Vector3(-0.58, 0.24, 0)
	torso_pivot.add_child(left_arm_pivot)
	left_forearm_pivot = _build_single_arm(left_arm_pivot, -1.0)

	right_arm_pivot = Node3D.new()
	right_arm_pivot.position = Vector3(0.58, 0.24, 0)
	torso_pivot.add_child(right_arm_pivot)
	right_forearm_pivot = _build_single_arm(right_arm_pivot, 1.0)

	# --- 右腕武器 3種 ---
	r_muzzle_marker = Marker3D.new()
	r_muzzle_marker.position = Vector3(0, -0.25, -0.95)
	right_forearm_pivot.add_child(r_muzzle_marker)

	# R-Wpn 0: PLASMA RIFLE
	var rw0 := Node3D.new()
	right_forearm_pivot.add_child(rw0)
	_add_box(rw0, Vector3(0.14, 0.22, 0.72), Vector3(0, -0.22, -0.35), Vector3.ZERO, mat_secondary)
	_add_cyl(rw0, 0.045, 0.045, 0.55, Vector3(0, -0.18, -0.68), Vector3(90, 0, 0), mat_chrome)
	_add_box(rw0, Vector3(0.16, 0.08, 0.42), Vector3(0, -0.14, -0.42), Vector3.ZERO, mat_glow)
	r_wpn_models.append(rw0)

	# R-Wpn 1: HEAVY GATLING (4連装回転バレル)
	var rw1 := Node3D.new()
	right_forearm_pivot.add_child(rw1)
	_add_box(rw1, Vector3(0.26, 0.28, 0.55), Vector3(0.06, -0.24, -0.25), Vector3.ZERO, mat_secondary)
	for bx in [-0.05, 0.05]:
		for by in [-0.05, 0.05]:
			_add_cyl(rw1, 0.03, 0.03, 0.75, Vector3(0.06 + bx, -0.24 + by, -0.68), Vector3(90, 0, 0), mat_chrome)
	_add_cyl(rw1, 0.13, 0.13, 0.08, Vector3(0.06, -0.24, -0.82), Vector3(90, 0, 0), mat_sub_glow)
	r_wpn_models.append(rw1)

	# R-Wpn 2: HYPER RAILGUN (長距離電磁加速砲)
	var rw2 := Node3D.new()
	right_forearm_pivot.add_child(rw2)
	_add_box(rw2, Vector3(0.20, 0.28, 0.65), Vector3(0, -0.20, -0.25), Vector3.ZERO, mat_primary)
	_add_box(rw2, Vector3(0.06, 0.10, 1.25), Vector3(-0.05, -0.18, -0.78), Vector3.ZERO, mat_chrome)
	_add_box(rw2, Vector3(0.06, 0.10, 1.25), Vector3(0.05, -0.18, -0.78), Vector3.ZERO, mat_chrome)
	_add_box(rw2, Vector3(0.04, 0.06, 1.15), Vector3(0, -0.18, -0.75), Vector3.ZERO, mat_glow)
	r_wpn_models.append(rw2)

	# --- 左腕武器 3種 ---
	l_muzzle_marker = Marker3D.new()
	l_muzzle_marker.position = Vector3(0, -0.25, -0.85)
	left_forearm_pivot.add_child(l_muzzle_marker)

	# L-Wpn 0: LASER BLADE (前腕マウント＋発光プラズマ刀身)
	var lw0 := Node3D.new()
	left_forearm_pivot.add_child(lw0)
	_add_box(lw0, Vector3(0.16, 0.16, 0.46), Vector3(-0.10, -0.18, -0.20), Vector3.ZERO, mat_primary)
	blade_effect_mesh = _add_box(lw0, Vector3(0.05, 0.14, 1.35), Vector3(-0.10, -0.18, -0.98), Vector3.ZERO, mat_blade)
	l_wpn_models.append(lw0)

	# L-Wpn 1: HEAVY BAZOOKA (大口径バズーカ砲)
	var lw1 := Node3D.new()
	left_forearm_pivot.add_child(lw1)
	_add_cyl(lw1, 0.14, 0.16, 1.15, Vector3(-0.08, -0.16, -0.42), Vector3(90, 0, 0), mat_secondary)
	_add_cyl(lw1, 0.16, 0.16, 0.15, Vector3(-0.08, -0.16, -0.95), Vector3(90, 0, 0), mat_sub_glow)
	l_wpn_models.append(lw1)

	# L-Wpn 2: AEGIS ENERGY SHIELD (大型エネルギーシールド)
	var lw2 := Node3D.new()
	left_forearm_pivot.add_child(lw2)
	_add_box(lw2, Vector3(0.12, 0.85, 0.56), Vector3(-0.22, -0.12, -0.15), Vector3(0, 15, 0), mat_primary)
	_add_box(lw2, Vector3(0.06, 1.12, 0.78), Vector3(-0.28, -0.12, -0.18), Vector3(0, 15, 0), mat_shield)
	l_wpn_models.append(lw2)

func _build_single_arm(shoulder_piv: Node3D, side: float) -> Node3D:
	# 大型ショルダーポールトロン（肩装甲）
	var pauldron := _add_prism(shoulder_piv, Vector3(0.46, 0.36, 0.56), Vector3(side * 0.14, 0.12, 0), Vector3(0, 0, side * -22), mat_primary)
	_add_box(pauldron, Vector3(0.48, 0.08, 0.58), Vector3(0, -0.12, 0), Vector3.ZERO, mat_glow)
	
	# 球体肩関節＋上腕シリンダー
	_add_sphere(shoulder_piv, 0.15, 0.30, Vector3(side * 0.06, -0.06, 0), mat_frame)
	_add_cyl(shoulder_piv, 0.11, 0.10, 0.36, Vector3(side * 0.08, -0.26, 0), Vector3.ZERO, mat_secondary)
	
	# 肘ピボット＋前腕＋5本指マニピュレーター（手）
	var forearm_piv := Node3D.new()
	forearm_piv.position = Vector3(side * 0.08, -0.44, 0)
	shoulder_piv.add_child(forearm_piv)
	
	_add_sphere(forearm_piv, 0.12, 0.24, Vector3.ZERO, mat_chrome)
	_add_box(forearm_piv, Vector3(0.22, 0.38, 0.26), Vector3(0, -0.20, -0.06), Vector3(18, 0, 0), mat_primary)
	
	# 手（ハンド＆指パーツ）
	var hand := _add_box(forearm_piv, Vector3(0.16, 0.16, 0.18), Vector3(0, -0.42, -0.14), Vector3.ZERO, mat_frame)
	for f in [-0.05, 0.0, 0.05]:
		_add_box(hand, Vector3(0.035, 0.12, 0.04), Vector3(f, -0.10, -0.06), Vector3(25, 0, 0), mat_chrome)
	return forearm_piv

func _build_back_units() -> void:
	back_wpn_models.clear()
	# バックパック本体＋メインブースターノズル2基
	var bp := _add_box(torso_pivot, Vector3(0.64, 0.54, 0.34), Vector3(0, 0.14, 0.36), Vector3.ZERO, mat_secondary)
	for s in [-1.0, 1.0]:
		var noz := _add_cyl(bp, 0.10, 0.15, 0.26, Vector3(s * 0.22, -0.14, 0.20), Vector3(65, 0, 0), mat_chrome)
		var flm := _add_cyl(noz, 0.12, 0.02, 0.55, Vector3(0, -0.35, 0), Vector3.ZERO, mat_flame)
		thruster_flames.append(flm)

	# Back 0: 6-CELL MISSILE PODS (両肩マルチミサイルコンテナ)
	var bw0 := Node3D.new()
	bp.add_child(bw0)
	for s in [-1.0, 1.0]:
		var pod := _add_box(bw0, Vector3(0.36, 0.42, 0.38), Vector3(s * 0.44, 0.36, 0.04), Vector3(-12, 0, s * -8), mat_primary)
		for mx in [-0.08, 0.08]:
			for my in [-0.10, 0.0, 0.10]:
				_add_cyl(pod, 0.04, 0.04, 0.08, Vector3(mx, my, -0.18), Vector3(90, 0, 0), mat_sub_glow)
	back_wpn_models.append(bw0)

	# Back 1: TWIN PHOTON CANNONS (両肩オーバーキャノン砲)
	var bw1 := Node3D.new()
	bp.add_child(bw1)
	for s in [-1.0, 1.0]:
		_add_box(bw1, Vector3(0.22, 0.26, 0.45), Vector3(s * 0.38, 0.38, 0.0), Vector3.ZERO, mat_secondary)
		_add_cyl(bw1, 0.08, 0.10, 1.25, Vector3(s * 0.38, 0.44, -0.55), Vector3(82, 0, 0), mat_chrome)
		_add_cyl(bw1, 0.09, 0.09, 0.25, Vector3(s * 0.38, 0.52, -1.12), Vector3(82, 0, 0), mat_glow)
	back_wpn_models.append(bw1)

	# Back 2: SERAPHIM WINGS (大型6枚ウイングバインダー＆光の翼)
	var bw2 := Node3D.new()
	bp.add_child(bw2)
	for s in [-1.0, 1.0]:
		for w_idx in range(3):
			var ang_z := s * (-35.0 - float(w_idx) * 22.0)
			var wing := _add_box(bw2, Vector3(0.10, 1.15, 0.32), Vector3(s * 0.55, 0.35 + float(w_idx) * 0.12, 0.12), Vector3(-18, 0, ang_z), mat_primary)
			_add_box(wing, Vector3(0.04, 1.35, 0.42), Vector3(0, 0.1, 0.18), Vector3.ZERO, mat_blade)
	back_wpn_models.append(bw2)

func _build_all_leg_types() -> void:
	leg_type_roots.clear()
	quad_leg_pivs.clear()

	var pelvis_root := Node3D.new()
	pelvis_root.position = Vector3(0, 0.72, 0)
	mecha_root.add_child(pelvis_root)
	_add_box(pelvis_root, Vector3(0.54, 0.24, 0.44), Vector3.ZERO, Vector3.ZERO, mat_secondary)

	# --- [0] BIPEDAL STANDARD LEGS ---
	var leg0 := Node3D.new()
	pelvis_root.add_child(leg0)
	biped_l_piv = Node3D.new()
	biped_l_piv.position = Vector3(-0.24, 0, 0)
	leg0.add_child(biped_l_piv)
	_build_biped_limb(biped_l_piv)

	biped_r_piv = Node3D.new()
	biped_r_piv.position = Vector3(0.24, 0, 0)
	leg0.add_child(biped_r_piv)
	_build_biped_limb(biped_r_piv)
	leg_type_roots.append(leg0)

	# --- [1] HOVER HIGH-SPEED THRUSTER LEGS ---
	var leg1 := Node3D.new()
	pelvis_root.add_child(leg1)
	for s in [-1.0, 1.0]:
		var pod := _add_box(leg1, Vector3(0.36, 0.34, 0.92), Vector3(s * 0.30, -0.36, 0.06), Vector3(-10, 0, s * -6), mat_primary)
		_add_prism(pod, Vector3(0.38, 0.28, 0.55), Vector3(0, 0.12, -0.32), Vector3(-90, 0, 0), mat_secondary)
		_add_cyl(pod, 0.22, 0.26, 0.12, Vector3(0, -0.20, 0), Vector3.ZERO, mat_glow)
		var flm := _add_cyl(pod, 0.14, 0.02, 0.65, Vector3(0, 0, 0.65), Vector3(90, 0, 0), mat_flame)
		thruster_flames.append(flm)
	leg_type_roots.append(leg1)

	# --- [2] REVERSE-JOINT (獣脚・鳥脚高跳躍型) ---
	var leg2 := Node3D.new()
	pelvis_root.add_child(leg2)
	rev_l_piv = Node3D.new()
	rev_l_piv.position = Vector3(-0.26, 0, 0)
	leg2.add_child(rev_l_piv)
	_build_reverse_joint_limb(rev_l_piv)

	rev_r_piv = Node3D.new()
	rev_r_piv.position = Vector3(0.26, 0, 0)
	leg2.add_child(rev_r_piv)
	_build_reverse_joint_limb(rev_r_piv)
	leg_type_roots.append(leg2)

	# --- [3] SPIDER QUAD-LEGS (重装4脚スパイダー型) ---
	var leg3 := Node3D.new()
	pelvis_root.add_child(leg3)
	_add_cyl(leg3, 0.48, 0.56, 0.28, Vector3(0, -0.08, 0), Vector3.ZERO, mat_secondary)
	var angles := [-42.0, 42.0, -138.0, 138.0]
	for ang in angles:
		var q_piv := Node3D.new()
		q_piv.rotation_degrees.y = ang
		leg3.add_child(q_piv)
		_add_box(q_piv, Vector3(0.20, 0.18, 0.62), Vector3(0, -0.06, -0.42), Vector3(22, 0, 0), mat_primary)
		_add_sphere(q_piv, 0.14, 0.28, Vector3(0, 0.06, -0.72), mat_glow)
		_add_cyl(q_piv, 0.10, 0.05, 0.78, Vector3(0, -0.32, -0.88), Vector3(-18, 0, 0), mat_secondary)
		_add_box(q_piv, Vector3(0.24, 0.10, 0.32), Vector3(0, -0.68, -0.98), Vector3.ZERO, mat_chrome)
		quad_leg_pivs.append(q_piv)
	leg_type_roots.append(leg3)

func _build_biped_limb(piv: Node3D) -> void:
	_add_sphere(piv, 0.13, 0.26, Vector3.ZERO, mat_frame)
	_add_cyl(piv, 0.14, 0.12, 0.38, Vector3(0, -0.20, 0), Vector3.ZERO, mat_primary)
	_add_prism(piv, Vector3(0.26, 0.28, 0.26), Vector3(0, -0.36, -0.10), Vector3(-90, 0, 0), mat_glow)
	_add_box(piv, Vector3(0.24, 0.38, 0.32), Vector3(0, -0.50, 0.02), Vector3.ZERO, mat_secondary)
	_add_prism(piv, Vector3(0.30, 0.16, 0.48), Vector3(0, -0.66, -0.08), Vector3(-90, 0, 0), mat_primary)

func _build_reverse_joint_limb(piv: Node3D) -> void:
	# 前方へ突き出す太腿 → 後方へ折れ曲がる逆関節 → 長い脛 → 鉤爪フット
	_add_box(piv, Vector3(0.22, 0.36, 0.24), Vector3(0, -0.14, -0.14), Vector3(-42, 0, 0), mat_primary)
	_add_sphere(piv, 0.12, 0.24, Vector3(0, -0.26, -0.28), mat_glow)
	_add_box(piv, Vector3(0.18, 0.38, 0.20), Vector3(0, -0.34, 0.04), Vector3(52, 0, 0), mat_secondary)
	_add_cyl(piv, 0.09, 0.06, 0.46, Vector3(0, -0.52, 0.12), Vector3(-24, 0, 0), mat_chrome)
	_add_prism(piv, Vector3(0.28, 0.14, 0.52), Vector3(0, -0.68, -0.06), Vector3(-90, 0, 0), mat_primary)

# --- プリミティブ生成ヘルパー ---
func _add_box(parent: Node3D, s: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = s
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _add_cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = 12
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _add_sphere(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 6
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _add_prism(parent: Node3D, s: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = s
	mi.mesh = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	return mi

# ==============================================================================
# カスタムガレージUI（画面右側のリアルタイム・アセンブルパネル）の構築
# ==============================================================================
func _build_garage_custom_ui() -> void:
	garage_panel = PanelContainer.new()
	garage_panel.name = "GaragePanel"
	garage_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	garage_panel.offset_left = -380.0
	garage_panel.offset_top = 16.0
	garage_panel.offset_right = -16.0
	garage_panel.offset_bottom = 582.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.10, 0.88)
	sb.border_width_left = 3
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.0, 0.78, 1.0, 0.9)
	sb.corner_radius_top_left = 6
	sb.corner_radius_bottom_left = 6
	garage_panel.add_theme_stylebox_override("panel", sb)
	hud_root.add_child(garage_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	garage_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# タイトルバー＋開閉/カメラ切替ボタン
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "⚙ AEGIS GARAGE // CUSTOMIZE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)

	var cam_btn := Button.new()
	cam_btn.text = "🎥 CAM [C]"
	cam_btn.pressed.connect(func():
		garage_cam_mode = not garage_cam_mode
		_refresh_assembly_state(false)
	)
	header.add_child(cam_btn)

	# パーツ選択行の生成
	_add_selector_row(vbox, "HEAD / EYES [1]", "eye", func(d):
		eye_mode = posmod(eye_mode + d, EYE_NAMES.size())
		_refresh_assembly_state(false)
	)
	_add_selector_row(vbox, "EARS / ANTENNA [4]", "ear", func(d):
		ear_type = posmod(ear_type + d, EAR_NAMES.size())
		_refresh_assembly_state(false)
	)
	_add_selector_row(vbox, "ARMOR CLASS [3]", "armor", func(d):
		armor_type = posmod(armor_type + d, ARMOR_NAMES.size())
		_refresh_assembly_state(false)
	)
	_add_selector_row(vbox, "LEGS TYPE [2]", "leg", func(d):
		leg_type = posmod(leg_type + d, LEG_NAMES.size())
		_refresh_assembly_state(false)
	)
	_add_selector_row(vbox, "R-ARM WEAPON", "r_wpn", func(d):
		r_wpn_type = posmod(r_wpn_type + d, R_WPN_NAMES.size())
		_refresh_assembly_state(false)
	)
	_add_selector_row(vbox, "L-ARM WEAPON", "l_wpn", func(d):
		l_wpn_type = posmod(l_wpn_type + d, L_WPN_NAMES.size())
		_refresh_assembly_state(false)
	)
	_add_selector_row(vbox, "SHOULDER UNIT", "back_wpn", func(d):
		back_wpn_type = posmod(back_wpn_type + d, BACK_WPN_NAMES.size())
		_refresh_assembly_state(false)
	)
	_add_selector_row(vbox, "COLOR THEME", "theme", func(d):
		color_theme = posmod(color_theme + d, THEME_NAMES.size())
		_apply_color_theme()
		_refresh_assembly_state(false)
	)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# プロポーション（大きさ）調整スライダー群
	_add_slider_row(vbox, "OVERALL SIZE", 0.6, 1.7, 1.0, func(v):
		scale_overall = v
		_apply_proportions()
	)
	_add_slider_row(vbox, "HAND / ARM SIZE", 0.6, 2.0, 1.0, func(v):
		scale_arms = v
		_apply_proportions()
	)
	_add_slider_row(vbox, "LEG SIZE", 0.7, 1.8, 1.0, func(v):
		scale_legs = v
		_apply_proportions()
	)
	_add_slider_row(vbox, "ARMOR BULK", 0.7, 1.8, 1.0, func(v):
		scale_armor = v
		_apply_proportions()
	)

	# クイックアクションボタン行（武器発射テスト＆ランダムアセンブル）
	var act_row := HBoxContainer.new()
	act_row.add_theme_constant_override("separation", 6)
	vbox.add_child(act_row)

	var fire_btn := Button.new()
	fire_btn.text = "🔥 FIRE ALL [Q]"
	fire_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fire_btn.pressed.connect(func():
		_fire_right_weapon()
		_fire_left_weapon()
		_fire_back_weapon()
	)
	act_row.add_child(fire_btn)

	var rand_btn := Button.new()
	rand_btn.text = "🎲 RANDOM BUILD"
	rand_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rand_btn.pressed.connect(_randomize_build)
	act_row.add_child(rand_btn)

func _add_selector_row(parent: Control, label_text: String, key: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 135
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
	row.add_child(lbl)

	var prev_b := Button.new()
	prev_b.text = "◀"
	prev_b.pressed.connect(func(): callback.call(-1))
	row.add_child(prev_b)

	var val_lbl := Label.new()
	val_lbl.text = "---"
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_lbl.add_theme_font_size_override("font_size", 12)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	row.add_child(val_lbl)
	ui_value_labels[key] = val_lbl

	var next_b := Button.new()
	next_b.text = "▶"
	next_b.pressed.connect(func(): callback.call(1))
	row.add_child(next_b)

func _add_slider_row(parent: Control, label_text: String, min_v: float, max_v: float, init_v: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 120
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.05
	slider.value = init_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var v_lbl := Label.new()
	v_lbl.text = "1.00x"
	v_lbl.custom_minimum_size.x = 44
	v_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(v_lbl)

	slider.value_changed.connect(func(v: float):
		v_lbl.text = "%.2fx" % v
		callback.call(v)
	)

func _randomize_build() -> void:
	eye_mode = randi() % 3
	ear_type = randi() % EAR_NAMES.size()
	armor_type = randi() % ARMOR_NAMES.size()
	leg_type = randi() % LEG_NAMES.size()
	r_wpn_type = randi() % R_WPN_NAMES.size()
	l_wpn_type = randi() % L_WPN_NAMES.size()
	back_wpn_type = randi() % BACK_WPN_NAMES.size()
	color_theme = randi() % THEME_NAMES.size()
	_apply_color_theme()
	_refresh_assembly_state(false)

func _apply_proportions() -> void:
	if not is_instance_valid(mecha_root):
		return
	mecha_root.scale = Vector3.ONE * scale_overall
	left_arm_pivot.scale = Vector3.ONE * scale_arms
	right_arm_pivot.scale = Vector3.ONE * scale_arms
	for lg in leg_type_roots:
		lg.scale = Vector3(scale_legs, scale_legs, scale_legs)
	for am in armor_models:
		am.scale = Vector3.ONE * scale_armor

# ==============================================================================
# 入力処理（WASD移動、1〜5パーツ切替、クリック/F/Qで武装攻撃、TabでUI開閉）
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				# 1キー：目パーツ（バイザー / モノアイ / 4眼 / 取り外し暗闇）切り替え
				eye_mode = posmod(eye_mode + 1, EYE_NAMES.size())
				_refresh_assembly_state(false)
			KEY_2:
				# 2キー：足パーツ（二足 / ホバー / 逆関節 / 4脚スパイダー）切り替え
				leg_type = posmod(leg_type + 1, LEG_NAMES.size())
				_refresh_assembly_state(false)
			KEY_3:
				# 3キー：装甲グレード（軽量 / 標準 / 重装）切り替え
				armor_type = posmod(armor_type + 1, ARMOR_NAMES.size())
				_refresh_assembly_state(false)
			KEY_4:
				# 4キー：耳・アンテナパーツ切り替え
				ear_type = posmod(ear_type + 1, EAR_NAMES.size())
				_refresh_assembly_state(false)
			KEY_5:
				# 5キー：武器セット一括ローテーション
				r_wpn_type = posmod(r_wpn_type + 1, R_WPN_NAMES.size())
				l_wpn_type = posmod(l_wpn_type + 1, L_WPN_NAMES.size())
				back_wpn_type = posmod(back_wpn_type + 1, BACK_WPN_NAMES.size())
				_refresh_assembly_state(false)
			KEY_C:
				garage_cam_mode = not garage_cam_mode
				_refresh_assembly_state(false)
			KEY_TAB:
				if garage_panel:
					garage_panel.visible = not garage_panel.visible
			KEY_F, KEY_K:
				_fire_left_weapon()
			KEY_Q, KEY_E:
				_fire_back_weapon()

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_fire_right_weapon()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_fire_left_weapon()

# ==============================================================================
# 武装アクション（右腕射撃・左腕ブレード/バズーカ・両肩ミサイル/キャノン）
# ==============================================================================
func _fire_right_weapon() -> void:
	if r_fire_cd > 0.0:
		return
	var forward := -visuals.global_transform.basis.z.normalized()
	var spawn_pos := r_muzzle_marker.global_position

	# 腕の反動アニメーション
	right_arm_pivot.rotation.x = 0.25

	match r_wpn_type:
		0: # PLASMA RIFLE
			r_fire_cd = 0.16
			_spawn_projectile(spawn_pos, forward * 28.0, Color(0.0, 0.9, 1.0), 0.16, 25.0, false)
		1: # HEAVY GATLING (3発同時拡散バースト)
			r_fire_cd = 0.08
			for i in range(2):
				var spread := forward.rotated(Vector3.UP, randf_range(-0.08, 0.08))
				_spawn_projectile(spawn_pos, spread * 32.0, Color(1.0, 0.65, 0.1), 0.11, 12.0, false)
		2: # HYPER RAILGUN (超高速貫通レーザー弾)
			r_fire_cd = 0.55
			right_arm_pivot.rotation.x = 0.55
			_spawn_projectile(spawn_pos, forward * 48.0, Color(0.4, 1.0, 1.0), 0.28, 65.0, false)

func _fire_left_weapon() -> void:
	if l_fire_cd > 0.0:
		return
	var forward := -visuals.global_transform.basis.z.normalized()
	var spawn_pos := l_muzzle_marker.global_position

	match l_wpn_type:
		0: # LASER BLADE (踏み込み回転斬撃スラッシュ！)
			l_fire_cd = 0.42
			blade_slash_timer = 0.28
			velocity += forward * 11.0
			var hit_center := global_position + Vector3(0, 1.2, 0) + forward * 2.2
			if arena_main and arena_main.has_method("check_hit_targets"):
				arena_main.check_hit_targets(hit_center, 2.6, 55.0)
				arena_main.spawn_explosion(hit_center, Color(0.0, 1.0, 0.9), 1.4)
		1: # HEAVY BAZOOKA
			l_fire_cd = 0.65
			left_arm_pivot.rotation.x = 0.5
			_spawn_projectile(spawn_pos, forward * 22.0, Color(1.0, 0.35, 0.1), 0.32, 70.0, false)
		2: # AEGIS SHIELD BASH
			l_fire_cd = 0.45
			left_arm_pivot.rotation.x = -0.6
			velocity += forward * 9.0
			var bash_pos := global_position + Vector3(0, 1.2, 0) + forward * 1.8
			if arena_main and arena_main.has_method("check_hit_targets"):
				arena_main.check_hit_targets(bash_pos, 2.2, 35.0)
				arena_main.spawn_explosion(bash_pos, Color(0.1, 0.7, 1.0), 1.1)

func _fire_back_weapon() -> void:
	if back_fire_cd > 0.0:
		return
	var forward := -visuals.global_transform.basis.z.normalized()

	match back_wpn_type:
		0: # 6-CELL MISSILE PODS (ホーミングミサイル6連射！)
			back_fire_cd = 1.1
			for i in range(6):
				var side := -1.0 if i % 2 == 0 else 1.0
				var m_pos := global_position + Vector3(side * 0.6, 1.9, 0)
				var launch_vel := (forward * 10.0 + Vector3(side * randf_range(3.0, 6.0), randf_range(6.0, 10.0), 0))
				_spawn_projectile(m_pos, launch_vel, Color(1.0, 0.45, 0.1), 0.18, 30.0, true)
		1: # TWIN PHOTON CANNONS
			back_fire_cd = 0.85
			for s in [-0.45, 0.45]:
				var c_pos := global_position + Vector3(s, 1.85, 0) + forward * 0.8
				_spawn_projectile(c_pos, forward * 42.0, Color(0.1, 0.95, 1.0), 0.26, 50.0, false)
		2: # SERAPHIM WING BOOST (ハイパーエアダッシュ！)
			back_fire_cd = 0.7
			velocity = forward * 22.0 + Vector3(0, 5.5, 0)
			if arena_main and arena_main.has_method("spawn_explosion"):
				arena_main.spawn_explosion(global_position + Vector3(0, 1.2, 0), Color(0.1, 1.0, 0.9), 1.6)

func _spawn_projectile(pos: Vector3, vel: Vector3, col: Color, radius: float, dmg: float, homing: bool) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = radius
	sp.height = radius * 2.0
	mi.mesh = sp
	mi.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.0
	mi.material_override = mat
	get_parent().add_child(mi)

	projectiles.append({
		"node": mi,
		"vel": vel,
		"dmg": dmg,
		"radius": radius,
		"homing": homing,
		"life": 2.2
	})

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p := projectiles[i]
		p["life"] -= delta
		var n: Node3D = p["node"]
		if p["life"] <= 0.0 or not is_instance_valid(n):
			if is_instance_valid(n):
				n.queue_free()
			projectiles.remove_at(i)
			continue

		if p["homing"] and arena_main and arena_main.has_method("get_nearest_target_pos"):
			var target_pos: Vector3 = arena_main.get_nearest_target_pos(n.global_position)
			var desired_dir := (target_pos - n.global_position).normalized()
			var cur_vel: Vector3 = p["vel"]
			p["vel"] = cur_vel.lerp(desired_dir * 26.0, 7.5 * delta)

		n.global_position += p["vel"] * delta

		# 着弾判定（敵ドローン または 地面）
		var hit := false
		if arena_main and arena_main.has_method("check_hit_targets"):
			if arena_main.check_hit_targets(n.global_position, p["radius"] + 0.35, p["dmg"]):
				hit = true
		if n.global_position.y <= 0.1:
			hit = true
			if arena_main and arena_main.has_method("spawn_explosion"):
				arena_main.spawn_explosion(n.global_position, Color(1.0, 0.55, 0.1), 0.8)

		if hit:
			n.queue_free()
			projectiles.remove_at(i)

# ==============================================================================
# 物理移動・脚部タイプ別モーション・カメラ・HUD更新
# ==============================================================================
func _physics_process(delta: float) -> void:
	r_fire_cd = maxf(0.0, r_fire_cd - delta)
	l_fire_cd = maxf(0.0, l_fire_cd - delta)
	back_fire_cd = maxf(0.0, back_fire_cd - delta)

	# 1. 脚部＆装甲タイプに応じた機動スペック計算
	var base_speeds := [6.5, 14.5, 9.5, 7.8] # Biped, Hover, Reverse-Joint, Spider-Quad
	var jump_powers := [8.0, 9.0, 13.5, 6.5] # 逆関節は超高跳躍！
	var armor_mults := [1.15, 1.0, 0.84]     # 軽量は速く、重装は重厚
	var wing_bonus := 1.12 if back_wpn_type == 2 else 1.0

	var max_speed: float = base_speeds[leg_type] * armor_mults[armor_type] * wing_bonus
	var jump_vel: float = jump_powers[leg_type]

	# 重力とジャンプ
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = jump_vel

	# 2. WASD / 矢印キー移動入力
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

	if input_dir != Vector2.ZERO:
		velocity.x = move_toward(velocity.x, input_dir.x * max_speed, 65.0 * delta)
		velocity.z = move_toward(velocity.z, input_dir.y * max_speed, 65.0 * delta)
		var target_angle := atan2(-input_dir.x, -input_dir.y)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, 14.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 48.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 48.0 * delta)

	move_and_slide()

	# 左クリック押しっぱなしで右腕武器連射（UI操作中を除く）
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_x := get_viewport().get_mouse_position().x
		var vp_w := get_viewport().get_visible_rect().size.x
		if not (garage_panel and garage_panel.visible and mouse_x > vp_w - 390.0):
			_fire_right_weapon()

	_animate_mecha_parts(delta)
	_update_projectiles(delta)
	_update_camera_system(delta, max_speed)
	_update_visor_and_telemetry(delta, max_speed)

func _animate_mecha_parts(delta: float) -> void:
	var horiz_spd := Vector2(velocity.x, velocity.z).length()
	var is_moving := horiz_spd > 0.25
	anim_time += delta * (horiz_spd * 1.6 if is_moving else 2.2)

	# 脚部タイプ別のアニメーション
	match leg_type:
		0: # BIPEDAL STANDARD
			if is_moving:
				var s := sin(anim_time) * 0.65
				biped_l_piv.rotation.x = s
				biped_r_piv.rotation.x = -s
				visuals.position.y = abs(cos(anim_time)) * 0.08
				visuals.rotation.x = lerp(visuals.rotation.x, -0.08, 10.0 * delta)
			else:
				biped_l_piv.rotation.x = lerp(biped_l_piv.rotation.x, 0.0, 12.0 * delta)
				biped_r_piv.rotation.x = lerp(biped_r_piv.rotation.x, 0.0, 12.0 * delta)
				visuals.position.y = lerp(visuals.position.y, 0.0, 10.0 * delta)
				visuals.rotation.x = lerp(visuals.rotation.x, 0.0, 10.0 * delta)
		1: # HOVER THRUSTERS
			var bob := 0.20 + sin(Time.get_ticks_msec() * 0.008) * 0.06
			visuals.position.y = lerp(visuals.position.y, bob, 10.0 * delta)
			visuals.rotation.x = lerp(visuals.rotation.x, -0.26 if is_moving else -0.04, 10.0 * delta)
		2: # REVERSE-JOINT
			if is_moving:
				var s := sin(anim_time * 1.1) * 0.78
				rev_l_piv.rotation.x = s
				rev_r_piv.rotation.x = -s
				visuals.position.y = abs(sin(anim_time * 1.1)) * 0.16
				visuals.rotation.x = lerp(visuals.rotation.x, -0.14, 10.0 * delta)
			else:
				rev_l_piv.rotation.x = lerp(rev_l_piv.rotation.x, 0.0, 12.0 * delta)
				rev_r_piv.rotation.x = lerp(rev_r_piv.rotation.x, 0.0, 12.0 * delta)
				visuals.position.y = lerp(visuals.position.y, 0.0, 10.0 * delta)
				visuals.rotation.x = lerp(visuals.rotation.x, 0.0, 10.0 * delta)
		3: # SPIDER QUAD-LEGS
			for idx in range(quad_leg_pivs.size()):
				var qp := quad_leg_pivs[idx]
				if is_moving:
					var phase := anim_time * 1.5 + float(idx) * 1.57
					qp.rotation.x = sin(phase) * 0.28
					qp.position.y = maxf(0.0, cos(phase) * 0.08)
				else:
					qp.rotation.x = lerp(qp.rotation.x, 0.0, 10.0 * delta)
					qp.position.y = lerp(qp.position.y, 0.0, 10.0 * delta)
			visuals.position.y = lerp(visuals.position.y, 0.04, 10.0 * delta)
			visuals.rotation.x = lerp(visuals.rotation.x, -0.05 if is_moving else 0.0, 10.0 * delta)

	# 腕の構え＆ブレード斬撃モーション
	right_arm_pivot.rotation.x = lerp(right_arm_pivot.rotation.x, -0.18 if is_moving else -0.08, 10.0 * delta)
	if blade_slash_timer > 0.0:
		blade_slash_timer -= delta
		left_arm_pivot.rotation.x = -1.1
		left_arm_pivot.rotation.y = sin((0.28 - blade_slash_timer) * 22.0) * 1.4
		if blade_effect_mesh:
			blade_effect_mesh.scale = Vector3(2.5, 1.5, 1.45)
	else:
		left_arm_pivot.rotation.x = lerp(left_arm_pivot.rotation.x, -0.15 if is_moving else -0.05, 10.0 * delta)
		left_arm_pivot.rotation.y = lerp(left_arm_pivot.rotation.y, 0.0, 12.0 * delta)
		if blade_effect_mesh:
			blade_effect_mesh.scale = blade_effect_mesh.scale.lerp(Vector3.ONE, 12.0 * delta)

	# スラスタージェット炎
	var flame_len := 0.1
	if leg_type == 1:
		flame_len = (1.35 + sin(Time.get_ticks_msec() * 0.05) * 0.35) if is_moving else 0.45
	elif is_moving or not is_on_floor():
		flame_len = 0.65
	for flm in thruster_flames:
		flm.visible = flame_len > 0.15
		flm.scale.y = flame_len

func _update_camera_system(delta: float, max_speed: float) -> void:
	if not is_instance_valid(main_camera):
		return
	if garage_cam_mode:
		# ガレージ鑑賞モード：機体の周囲をゆっくり回転しながらドアップで映す
		garage_orbit_angle += delta * 0.45
		var cam_offset := Vector3(sin(garage_orbit_angle) * 3.8, 2.2 * scale_overall, cos(garage_orbit_angle) * 3.8)
		var target_pos := global_position + cam_offset
		main_camera.global_position = main_camera.global_position.lerp(target_pos, 8.0 * delta)
		main_camera.look_at(global_position + Vector3(0, 1.2 * scale_overall, 0), Vector3.UP)
		main_camera.fov = lerp(main_camera.fov, 45.0, 6.0 * delta)
	else:
		# 見下ろしタクティカル戦闘カメラ
		var look_ahead := Vector3(velocity.x, 0, velocity.z) * 0.20
		var cam_dist := 11.5 if eye_mode != 1 else 14.5 # スナイパーモノアイ時は広域視界
		var target_pos := global_position + look_ahead + Vector3(0, cam_dist, cam_dist * 0.74)
		main_camera.global_position = main_camera.global_position.lerp(target_pos, 6.5 * delta)
		var desired_Basis := Basis.from_euler(Vector3(deg_to_rad(-54.0), 0.0, 0.0))
		main_camera.global_transform.basis = main_camera.global_transform.basis.slerp(desired_Basis, 8.0 * delta)
		var spd := Vector2(velocity.x, velocity.z).length()
		main_camera.fov = lerp(main_camera.fov, 55.0 + (spd / max_speed) * 9.0, 5.0 * delta)

func _update_visor_and_telemetry(delta: float, max_speed: float) -> void:
	current_blind_amount = lerp(current_blind_amount, target_blind_amount, 8.0 * delta)
	if blind_overlay and blind_overlay.material is ShaderMaterial:
		var sm: ShaderMaterial = blind_overlay.material
		sm.set_shader_parameter("blind_amount", current_blind_amount)
		if is_instance_valid(main_camera):
			var screen_pos := main_camera.unproject_position(global_position + Vector3(0, 1.1, 0))
			var vp_size := get_viewport().get_visible_rect().size
			if vp_size.x > 0 and vp_size.y > 0:
				sm.set_shader_parameter("player_screen_pos", screen_pos / vp_size)

	if telemetry_label:
		var spd := Vector2(velocity.x, velocity.z).length()
		telemetry_label.text = "SPEED: %05.2f / %.1f m/s  |  [WASD] MOVE  [SPACE] JUMP  [L-CLICK] R-FIRE  [R-CLICK/F] L-ATTACK  [Q] SHOULDER  [1-5] QUICK SWAP  [C] CAM" % [
			spd, max_speed
		]

# ==============================================================================
# アセンブル状態の反映 ＆ UI表示更新
# ==============================================================================
func _refresh_assembly_state(immediate: bool = false) -> void:
	var has_head := (eye_mode < 3)
	head_pivot.visible = has_head
	neck_spark_mesh.visible = not has_head

	for i in range(eye_models.size()):
		eye_models[i].visible = (i == eye_mode)
	for i in range(ear_models.size()):
		ear_models[i].visible = (i == ear_type)
	for i in range(armor_models.size()):
		armor_models[i].visible = (i == armor_type)
	for i in range(leg_type_roots.size()):
		leg_type_roots[i].visible = (i == leg_type)
	for i in range(r_wpn_models.size()):
		r_wpn_models[i].visible = (i == r_wpn_type)
	for i in range(l_wpn_models.size()):
		l_wpn_models[i].visible = (i == l_wpn_type)
	for i in range(back_wpn_models.size()):
		back_wpn_models[i].visible = (i == back_wpn_type)

	target_blind_amount = 0.0 if has_head else 1.0
	if immediate:
		current_blind_amount = target_blind_amount
	if warning_banner:
		warning_banner.visible = not has_head

	_apply_proportions()

	# 換装時のメカニカルバウンス演出
	if not immediate and visuals:
		var tw := create_tween()
		tw.tween_property(visuals, "scale", Vector3(1.12, 0.90, 1.12), 0.06)
		tw.tween_property(visuals, "scale", Vector3.ONE, 0.12)

	# ガレージUIの値ラベル更新
	if ui_value_labels.has("eye"):
		ui_value_labels["eye"].text = EYE_NAMES[eye_mode]
		ui_value_labels["ear"].text = EAR_NAMES[ear_type]
		ui_value_labels["armor"].text = ARMOR_NAMES[armor_type]
		ui_value_labels["leg"].text = LEG_NAMES[leg_type]
		ui_value_labels["r_wpn"].text = R_WPN_NAMES[r_wpn_type]
		ui_value_labels["l_wpn"].text = L_WPN_NAMES[l_wpn_type]
		ui_value_labels["back_wpn"].text = BACK_WPN_NAMES[back_wpn_type]
		ui_value_labels["theme"].text = THEME_NAMES[color_theme]

	# 左上ステータスモニター更新
	if status_label:
		status_label.text = (
			"[b][color=#00e5ff]AEGIS-CUSTOM // TACTICAL LOADOUT[/color][/b]\n" +
			"[color=#446688]────────────────────────────────────[/color]\n" +
			"[b]HEAD / EARS :[/b] [color=#88eeff]%s[/color] / [color=#aaddff]%s[/color]\n" % [EYE_NAMES[eye_mode], EAR_NAMES[ear_type]] +
			"[b]ARMOR / LEGS:[/b] [color=#ffcc44]%s[/color] / [color=#ff9944]%s[/color]\n" % [ARMOR_NAMES[armor_type], LEG_NAMES[leg_type]] +
			"[b]WEAPONS     :[/b] [color=#66ff99]%s[/color] | [color=#66ff99]%s[/color] | [color=#ff77aa]%s[/color]" % [R_WPN_NAMES[r_wpn_type], L_WPN_NAMES[l_wpn_type], BACK_WPN_NAMES[back_wpn_type]]
		)
