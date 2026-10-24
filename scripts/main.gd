extends Node3D

# --- SF Proving Grounds (ステージ演出スクリプト) ---
var floating_cores: Array[Node3D] = []
var rotating_rings: Array[Node3D] = []
var time_acc: float = 0.0

func _ready() -> void:
	_build_sci_fi_arena_details()

func _process(delta: float) -> void:
	time_acc += delta
	
	# 浮遊エネルギーコアの上下運動＆回転
	for i in range(floating_cores.size()):
		var core := floating_cores[i]
		if is_instance_valid(core):
			core.position.y = 1.6 + sin(time_acc * 2.2 + float(i) * 1.3) * 0.3
			core.rotation.y += delta * 1.2
			core.rotation.x = sin(time_acc * 1.5 + float(i)) * 0.35

	# 中央および各所のホログラムリングの回転
	for i in range(rotating_rings.size()):
		var ring := rotating_rings[i]
		if is_instance_valid(ring):
			ring.rotation.y += delta * (0.6 if i % 2 == 0 else -0.8)

func _build_sci_fi_arena_details() -> void:
	var props_root := Node3D.new()
	props_root.name = "ArenaProps"
	add_child(props_root)

	# 共通マテリアル
	var mat_dark_metal := StandardMaterial3D.new()
	mat_dark_metal.albedo_color = Color(0.12, 0.14, 0.18)
	mat_dark_metal.metallic = 0.75
	mat_dark_metal.roughness = 0.3

	var mat_cyan_glow := StandardMaterial3D.new()
	mat_cyan_glow.albedo_color = Color(0.1, 0.9, 1.0)
	mat_cyan_glow.emission_enabled = true
	mat_cyan_glow.emission = Color(0.0, 0.8, 1.0)
	mat_cyan_glow.emission_energy_multiplier = 2.2

	var mat_amber_glow := StandardMaterial3D.new()
	mat_amber_glow.albedo_color = Color(1.0, 0.55, 0.1)
	mat_amber_glow.emission_enabled = true
	mat_amber_glow.emission = Color(1.0, 0.45, 0.0)
	mat_amber_glow.emission_energy_multiplier = 2.2

	# 1. 四方のハイテク発光ピラー＆ポイントライト（計8本）
	var pillar_coords := [
		Vector3(-7, 0, -7), Vector3(7, 0, -7),
		Vector3(-7, 0, 7), Vector3(7, 0, 7),
		Vector3(0, 0, -11), Vector3(0, 0, 11),
		Vector3(-11, 0, 0), Vector3(11, 0, 0)
	]

	for i in range(pillar_coords.size()):
		var pos: Vector3 = pillar_coords[i]
		var is_amber := (i % 2 == 1)
		var glow_mat := mat_amber_glow if is_amber else mat_cyan_glow
		
		var pillar_body := StaticBody3D.new()
		pillar_body.position = pos
		props_root.add_child(pillar_body)
		
		# 柱の本体
		var p_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.2, 3.6, 1.2)
		p_mesh.mesh = box
		p_mesh.position = Vector3(0, 1.8, 0)
		p_mesh.material_override = mat_dark_metal
		pillar_body.add_child(p_mesh)
		
		# 当たり判定
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.2, 3.6, 1.2)
		col.shape = shape
		col.position = Vector3(0, 1.8, 0)
		pillar_body.add_child(col)
		
		# 柱のネオン発光ライン
		var strip := MeshInstance3D.new()
		var s_box := BoxMesh.new()
		s_box.size = Vector3(1.26, 0.25, 1.26)
		strip.mesh = s_box
		strip.position = Vector3(0, 2.8, 0)
		strip.material_override = glow_mat
		pillar_body.add_child(strip)

		var strip_low := MeshInstance3D.new()
		strip_low.mesh = s_box
		strip_low.position = Vector3(0, 0.6, 0)
		strip_low.material_override = glow_mat
		pillar_body.add_child(strip_low)
		
		# 浮遊エネルギーコア（最初の4箇所）
		if i < 4:
			var core_holder := Node3D.new()
			core_holder.position = pos + Vector3(0, 1.6, 0) * 0.0 + Vector3(pos.x * -0.35, 1.6, pos.z * -0.35)
			props_root.add_child(core_holder)
			
			var core_mesh := MeshInstance3D.new()
			var prism := BoxMesh.new()
			prism.size = Vector3(0.55, 0.55, 0.55)
			core_mesh.mesh = prism
			core_mesh.rotation_degrees = Vector3(45, 45, 0)
			core_mesh.material_override = glow_mat
			core_holder.add_child(core_mesh)
			
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.5, 0.1) if is_amber else Color(0.0, 0.85, 1.0)
			light.light_energy = 1.6
			light.omni_range = 6.5
			core_holder.add_child(light)
			
			floating_cores.append(core_holder)

	# 2. 外周のローバリア（境界壁）
	var wall_configs := [
		{"pos": Vector3(0, 0.4, -14), "size": Vector3(28, 0.8, 0.5)},
		{"pos": Vector3(0, 0.4, 14),  "size": Vector3(28, 0.8, 0.5)},
		{"pos": Vector3(-14, 0.4, 0), "size": Vector3(0.5, 0.8, 28)},
		{"pos": Vector3(14, 0.4, 0),  "size": Vector3(0.5, 0.8, 28)}
	]
	for cfg in wall_configs:
		var w_body := StaticBody3D.new()
		w_body.position = cfg["pos"]
		props_root.add_child(w_body)
		
		var w_mesh := MeshInstance3D.new()
		var w_box := BoxMesh.new()
		w_box.size = cfg["size"]
		w_mesh.mesh = w_box
		w_mesh.material_override = mat_dark_metal
		w_body.add_child(w_mesh)
		
		var w_col := CollisionShape3D.new()
		var w_shape := BoxShape3D.new()
		w_shape.size = cfg["size"]
		w_col.shape = w_shape
		w_body.add_child(w_col)
		
		# 上部の発光ライン
		var top_glow := MeshInstance3D.new()
		var tg_box := BoxMesh.new()
		var s: Vector3 = cfg["size"]
		tg_box.size = Vector3(s.x, 0.08, s.z)
		top_glow.mesh = tg_box
		top_glow.position = Vector3(0, 0.42, 0)
		top_glow.material_override = mat_cyan_glow
		w_body.add_child(top_glow)

	# 3. 中央のホログラム・サークルモニュメント
	var center_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.85
	torus.outer_radius = 4.0
	center_ring.mesh = torus
	center_ring.position = Vector3(0, 0.05, 0)
	center_ring.material_override = mat_cyan_glow
	props_root.add_child(center_ring)
	rotating_rings.append(center_ring)
