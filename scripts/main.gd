extends Node3D

# ==============================================================================
# CYBERNETIC PROVING GROUNDS & TARGET DRONE SYSTEM
# ==============================================================================

var floating_cores: Array[Node3D] = []
var rotating_rings: Array[Node3D] = []
var target_drones: Array[Dictionary] = []
var active_effects: Array[Dictionary] = []
var time_acc: float = 0.0

var mat_dark_metal := StandardMaterial3D.new()
var mat_cyan_glow := StandardMaterial3D.new()
var mat_amber_glow := StandardMaterial3D.new()
var mat_enemy_armor := StandardMaterial3D.new()
var mat_enemy_eye := StandardMaterial3D.new()
var mat_hit_flash := StandardMaterial3D.new()

func _ready() -> void:
	_init_materials()
	_build_sci_fi_arena_details()
	_spawn_combat_targets()

func _init_materials() -> void:
	mat_dark_metal.albedo_color = Color(0.11, 0.13, 0.17)
	mat_dark_metal.metallic = 0.78
	mat_dark_metal.roughness = 0.28

	mat_cyan_glow.albedo_color = Color(0.1, 0.9, 1.0)
	mat_cyan_glow.emission_enabled = true
	mat_cyan_glow.emission = Color(0.0, 0.8, 1.0)
	mat_cyan_glow.emission_energy_multiplier = 2.4

	mat_amber_glow.albedo_color = Color(1.0, 0.55, 0.1)
	mat_amber_glow.emission_enabled = true
	mat_amber_glow.emission = Color(1.0, 0.45, 0.0)
	mat_amber_glow.emission_energy_multiplier = 2.4

	mat_enemy_armor.albedo_color = Color(0.25, 0.18, 0.22)
	mat_enemy_armor.metallic = 0.7
	mat_enemy_armor.roughness = 0.3

	mat_enemy_eye.albedo_color = Color(1.0, 0.15, 0.2)
	mat_enemy_eye.emission_enabled = true
	mat_enemy_eye.emission = Color(1.0, 0.05, 0.1)
	mat_enemy_eye.emission_energy_multiplier = 3.2

	mat_hit_flash.albedo_color = Color(1.0, 1.0, 1.0)
	mat_hit_flash.emission_enabled = true
	mat_hit_flash.emission = Color(1.0, 0.85, 0.5)
	mat_hit_flash.emission_energy_multiplier = 4.0

func _process(delta: float) -> void:
	time_acc += delta
	
	# 浮遊エネルギーコア
	for i in range(floating_cores.size()):
		var core := floating_cores[i]
		if is_instance_valid(core):
			core.position.y = 1.8 + sin(time_acc * 2.2 + float(i) * 1.3) * 0.35
			core.rotation.y += delta * 1.2
			core.rotation.x = sin(time_acc * 1.5 + float(i)) * 0.35

	# 中央リングの回転
	for i in range(rotating_rings.size()):
		var ring := rotating_rings[i]
		if is_instance_valid(ring):
			ring.rotation.y += delta * (0.5 if i % 2 == 0 else -0.7)

	# 敵ターゲットドローンのパトロール・ホバー挙動＆リスポーン管理
	_update_target_drones(delta)

	# 爆発・ヒットエフェクトの更新
	_update_effects(delta)

func _build_sci_fi_arena_details() -> void:
	var props_root := Node3D.new()
	props_root.name = "ArenaProps"
	add_child(props_root)

	# 四方の大型ハイテクピラー
	var pillar_coords := [
		Vector3(-9, 0, -9), Vector3(9, 0, -9),
		Vector3(-9, 0, 9),  Vector3(9, 0, 9),
		Vector3(0, 0, -13), Vector3(0, 0, 13),
		Vector3(-13, 0, 0), Vector3(13, 0, 0)
	]

	for i in range(pillar_coords.size()):
		var pos: Vector3 = pillar_coords[i]
		var is_amber := (i % 2 == 1)
		var glow_mat := mat_amber_glow if is_amber else mat_cyan_glow
		
		var pillar_body := StaticBody3D.new()
		pillar_body.position = pos
		props_root.add_child(pillar_body)
		
		# 八角柱風の重厚な柱（シリンダー＋装甲リブ）
		var p_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.75
		cyl.bottom_radius = 0.9
		cyl.height = 4.2
		cyl.radial_segments = 8
		p_mesh.mesh = cyl
		p_mesh.position = Vector3(0, 2.1, 0)
		p_mesh.material_override = mat_dark_metal
		pillar_body.add_child(p_mesh)
		
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.85
		shape.height = 4.2
		col.shape = shape
		col.position = Vector3(0, 2.1, 0)
		pillar_body.add_child(col)
		
		# 発光トーラスリング
		for h in [0.8, 2.2, 3.6]:
			var ring := MeshInstance3D.new()
			var tr := TorusMesh.new()
			tr.inner_radius = 0.82
			tr.outer_radius = 0.96
			ring.mesh = tr
			ring.position = Vector3(0, h, 0)
			ring.material_override = glow_mat
			pillar_body.add_child(ring)

		if i < 4:
			var core_holder := Node3D.new()
			core_holder.position = Vector3(pos.x * 0.65, 1.8, pos.z * 0.65)
			props_root.add_child(core_holder)
			
			var core_mesh := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.35
			sphere.height = 0.7
			core_mesh.mesh = sphere
			core_mesh.material_override = glow_mat
			core_holder.add_child(core_mesh)

			var orbit_ring := MeshInstance3D.new()
			var o_torus := TorusMesh.new()
			o_torus.inner_radius = 0.52
			o_torus.outer_radius = 0.58
			orbit_ring.mesh = o_torus
			orbit_ring.rotation_degrees = Vector3(35, 0, 25)
			orbit_ring.material_override = mat_dark_metal
			core_holder.add_child(orbit_ring)
			
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.5, 0.1) if is_amber else Color(0.0, 0.85, 1.0)
			light.light_energy = 1.8
			light.omni_range = 8.0
			core_holder.add_child(light)
			
			floating_cores.append(core_holder)

	# 外周バリアウォール
	var wall_configs := [
		{"pos": Vector3(0, 0.5, -15.5), "size": Vector3(31, 1.0, 0.6)},
		{"pos": Vector3(0, 0.5, 15.5),  "size": Vector3(31, 1.0, 0.6)},
		{"pos": Vector3(-15.5, 0.5, 0), "size": Vector3(0.6, 1.0, 31)},
		{"pos": Vector3(15.5, 0.5, 0),  "size": Vector3(0.6, 1.0, 31)}
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
		
		var top_glow := MeshInstance3D.new()
		var tg_box := BoxMesh.new()
		var s: Vector3 = cfg["size"]
		tg_box.size = Vector3(s.x, 0.1, s.z)
		top_glow.mesh = tg_box
		top_glow.position = Vector3(0, 0.52, 0)
		top_glow.material_override = mat_cyan_glow
		w_body.add_child(top_glow)

	# 中央のホログラムサークル
	var center_ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.35
	torus.outer_radius = 4.5
	center_ring.mesh = torus
	center_ring.position = Vector3(0, 0.04, 0)
	center_ring.material_override = mat_cyan_glow
	props_root.add_child(center_ring)
	rotating_rings.append(center_ring)

# --- 射撃・ブレード・ミサイルの標的となる敵コンバットドローンを配置 ---
func _spawn_combat_targets() -> void:
	var spawn_points := [
		Vector3(-5.0, 0.0, -5.0),
		Vector3(5.0, 0.0, -5.0),
		Vector3(-6.5, 0.0, 3.5),
		Vector3(6.5, 0.0, 3.5),
		Vector3(0.0, 0.0, -8.5)
	]

	for i in range(spawn_points.size()):
		var root := Node3D.new()
		root.name = "TargetDrone_%d" % i
		root.position = spawn_points[i]
		add_child(root)

		var visual := Node3D.new()
		root.add_child(visual)

		# ドローン胴体（多面体コア＋装甲リング＋赤いモノアイ＋両脇のガンポッド）
		var core := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.65
		sp.height = 1.2
		sp.radial_segments = 12
		sp.rings = 6
		core.mesh = sp
		core.position = Vector3(0, 1.3, 0)
		core.material_override = mat_enemy_armor
		visual.add_child(core)

		var shield_ring := MeshInstance3D.new()
		var tr := TorusMesh.new()
		tr.inner_radius = 0.78
		tr.outer_radius = 0.95
		shield_ring.mesh = tr
		shield_ring.position = Vector3(0, 1.3, 0)
		shield_ring.rotation_degrees.x = 15.0
		shield_ring.material_override = mat_dark_metal
		visual.add_child(shield_ring)

		var eye := MeshInstance3D.new()
		var e_sp := SphereMesh.new()
		e_sp.radius = 0.25
		e_sp.height = 0.5
		eye.mesh = e_sp
		eye.position = Vector3(0, 1.35, -0.55)
		eye.material_override = mat_enemy_eye
		visual.add_child(eye)

		# HPバー（頭上の発光バー）
		var hp_bg := MeshInstance3D.new()
		var bg_box := BoxMesh.new()
		bg_box.size = Vector3(1.4, 0.12, 0.06)
		hp_bg.mesh = bg_box
		hp_bg.position = Vector3(0, 2.35, 0)
		hp_bg.material_override = mat_dark_metal
		visual.add_child(hp_bg)

		var hp_fill := MeshInstance3D.new()
		var fill_box := BoxMesh.new()
		fill_box.size = Vector3(1.36, 0.09, 0.08)
		hp_fill.mesh = fill_box
		hp_fill.position = Vector3(0, 2.35, 0)
		hp_fill.material_override = mat_enemy_eye
		visual.add_child(hp_fill)

		target_drones.append({
			"root": root,
			"visual": visual,
			"core_mesh": core,
			"hp_fill": hp_fill,
			"base_pos": spawn_points[i],
			"hp": 100.0,
			"max_hp": 100.0,
			"alive": true,
			"respawn_timer": 0.0,
			"flash_timer": 0.0,
			"phase": float(i) * 1.4
		})

func _update_target_drones(delta: float) -> void:
	for d in target_drones:
		if not d["alive"]:
			d["respawn_timer"] -= delta
			if d["respawn_timer"] <= 0.0:
				d["alive"] = true
				d["hp"] = d["max_hp"]
				d["root"].visible = true
				d["hp_fill"].scale.x = 1.0
				spawn_explosion(d["root"].global_position + Vector3(0, 1.3, 0), Color(0.0, 0.85, 1.0), 1.2)
			continue

		var p: float = d["phase"] + time_acc * 1.6
		var base: Vector3 = d["base_pos"]
		d["root"].position = base + Vector3(sin(p) * 1.2, 0.15 * sin(p * 2.0), cos(p * 0.8) * 0.8)
		d["visual"].rotation.y = sin(p * 0.5) * 0.6

		if d["flash_timer"] > 0.0:
			d["flash_timer"] -= delta
			if d["flash_timer"] <= 0.0:
				d["core_mesh"].material_override = mat_enemy_armor

# --- プレイヤーの攻撃との当たり判定・ダメージ処理 ---
func check_hit_targets(world_pos: Vector3, radius: float, damage: float) -> bool:
	var hit_any := false
	for d in target_drones:
		if not d["alive"]:
			continue
		var center: Vector3 = d["root"].global_position + Vector3(0, 1.3, 0)
		if center.distance_to(world_pos) <= (radius + 0.85):
			hit_any = true
			d["hp"] -= damage
			d["flash_timer"] = 0.08
			d["core_mesh"].material_override = mat_hit_flash
			var ratio := clampf(d["hp"] / d["max_hp"], 0.0, 1.0)
			d["hp_fill"].scale.x = max(ratio, 0.01)
			spawn_explosion(world_pos, Color(1.0, 0.6, 0.1), 0.7)

			if d["hp"] <= 0.0:
				d["alive"] = false
				d["root"].visible = false
				d["respawn_timer"] = 3.5
				spawn_explosion(center, Color(1.0, 0.25, 0.1), 2.4)
	return hit_any

func get_nearest_target_pos(from_pos: Vector3) -> Vector3:
	var best_pos := from_pos + Vector3(0, 1.0, -8.0)
	var best_dist := 999.0
	for d in target_drones:
		if not d["alive"]:
			continue
		var c: Vector3 = d["root"].global_position + Vector3(0, 1.3, 0)
		var dist := from_pos.distance_to(c)
		if dist < best_dist:
			best_dist = dist
			best_pos = c
	return best_pos

func spawn_explosion(pos: Vector3, color: Color, scale_mult: float = 1.0) -> void:
	var mesh_inst := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.5 * scale_mult
	sp.height = 1.0 * scale_mult
	mesh_inst.mesh = sp
	mesh_inst.position = pos

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	active_effects.append({
		"node": mesh_inst,
		"mat": mat,
		"time": 0.0,
		"duration": 0.28 * clampf(scale_mult, 0.8, 1.8)
	})

func _update_effects(delta: float) -> void:
	for i in range(active_effects.size() - 1, -1, -1):
		var ef := active_effects[i]
		ef["time"] += delta
		var t: float = ef["time"] / ef["duration"]
		if t >= 1.0:
			if is_instance_valid(ef["node"]):
				ef["node"].queue_free()
			active_effects.remove_at(i)
		else:
			var n: Node3D = ef["node"]
			var m: StandardMaterial3D = ef["mat"]
			n.scale = Vector3.ONE * (1.0 + t * 2.2)
			m.albedo_color.a = 1.0 - t
