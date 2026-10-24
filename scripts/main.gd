extends Node2D

@onready var network_mgr = $NetworkManager
@onready var players_container = $World/Players
@onready var status_label = $CanvasLayer/UI/TopBar/StatusLabel
@onready var connect_btn = $CanvasLayer/UI/LoginPanel/VBoxContainer/ConnectButton
@onready var offline_btn = $CanvasLayer/UI/LoginPanel/VBoxContainer/OfflineButton
@onready var disconnect_btn = $CanvasLayer/UI/TopBar/DisconnectButton
@onready var login_panel = $CanvasLayer/UI/LoginPanel
@onready var name_input = $CanvasLayer/UI/LoginPanel/VBoxContainer/NameEdit
@onready var url_input = $CanvasLayer/UI/LoginPanel/VBoxContainer/URLEdit
@onready var chat_log = $CanvasLayer/UI/ChatPanel/RichTextLabel

var player_scene = preload("res://scenes/player.tscn")
var local_player: Player = null
var remote_players: Dictionary = {}

func _ready() -> void:
	# ネットワークシグナル接続
	network_mgr.connected_to_server.connect(_on_connected)
	network_mgr.connection_closed.connect(_on_disconnected)
	network_mgr.player_joined.connect(_on_player_joined)
	network_mgr.player_left.connect(_on_player_left)
	network_mgr.player_moved.connect(_on_player_moved)
	network_mgr.player_acted.connect(_on_player_acted)
	network_mgr.chat_received.connect(_on_chat_received)
	
	connect_btn.pressed.connect(_on_connect_pressed)
	offline_btn.pressed.connect(_on_offline_pressed)
	disconnect_btn.pressed.connect(_on_disconnect_pressed)
	
	# デフォルト値
	var rand_name = "Player_" + str(randi() % 1000)
	name_input.text = rand_name
	# WebSocketのデフォルトURL（ローカルテスト用 または Glitch/Render/無料WSS等）
	url_input.text = "ws://localhost:8080"
	
	status_label.text = "Status: Not Connected"
	disconnect_btn.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if local_player != null:
			local_player.play_action_effect("pulse")
			network_mgr.send_action("pulse")

func _on_connect_pressed() -> void:
	var url = url_input.text.strip_edges()
	var p_name = name_input.text.strip_edges()
	if url.is_empty():
		log_message("[color=red]Error: Please enter a WebSocket URL[/color]")
		return
	if p_name.is_empty():
		p_name = "Anonymous"
		
	status_label.text = "Status: Connecting to " + url + "..."
	log_message("[color=yellow]Connecting to " + url + "...[/color]")
	
	var rand_color = Color.from_hsv(randf(), 0.7, 0.9).to_html()
	network_mgr.connect_to_server(url, p_name, "#" + rand_color)

func _on_offline_pressed() -> void:
	# オフライン・ソロモードで起動
	login_panel.visible = false
	status_label.text = "Status: Solo Mode (Offline)"
	disconnect_btn.visible = true
	disconnect_btn.text = "Exit Solo"
	_spawn_local_player("solo", name_input.text, Color(0.2, 0.8, 0.4))
	log_message("[color=green]Started in Offline Solo Mode! Use WASD or Arrows to move.[/color]")

func _on_disconnect_pressed() -> void:
	network_mgr.disconnect_from_server()
	_cleanup_all_players()
	login_panel.visible = true
	disconnect_btn.visible = false
	status_label.text = "Status: Disconnected"
	log_message("[color=gray]Left the game.[/color]")

func _on_connected() -> void:
	login_panel.visible = false
	disconnect_btn.visible = true
	disconnect_btn.text = "Disconnect"
	status_label.text = "Status: Connected as " + network_mgr.my_name
	log_message("[color=green]Connected to server successfully![/color]")
	
	# ローカルプレイヤーを生成
	var col = Color.html(network_mgr.my_color_hex)
	_spawn_local_player(network_mgr.my_id, network_mgr.my_name, col)

func _on_disconnected() -> void:
	_cleanup_all_players()
	login_panel.visible = true
	disconnect_btn.visible = false
	status_label.text = "Status: Disconnected from server"
	log_message("[color=red]Disconnected from server.[/color]")

func _on_player_joined(id: String, p_name: String, x: float, y: float, color_hex: String) -> void:
	if id == network_mgr.my_id:
		return
	if remote_players.has(id):
		return
		
	var new_player: Player = player_scene.instantiate()
	players_container.add_child(new_player)
	var col = Color.html(color_hex)
	new_player.position = Vector2(x, y)
	new_player.setup(id, p_name, col, false)
	remote_players[id] = new_player
	
	log_message("[color=cyan]" + p_name + " joined the room![/color]")

func _on_player_left(id: String) -> void:
	if remote_players.has(id):
		var p = remote_players[id]
		log_message("[color=orange]" + p.player_name + " left the room.[/color]")
		p.queue_free()
		remote_players.erase(id)

func _on_player_moved(id: String, x: float, y: float) -> void:
	if remote_players.has(id):
		remote_players[id].set_remote_position(Vector2(x, y))

func _on_player_acted(id: String, action_type: String, _extra: Dictionary) -> void:
	if remote_players.has(id):
		remote_players[id].play_action_effect(action_type)

func _on_chat_received(sender: String, text: String) -> void:
	log_message("<b>" + sender + ":</b> " + text)

func _spawn_local_player(id: String, p_name: String, color: Color) -> void:
	if local_player != null:
		local_player.queue_free()
	local_player = player_scene.instantiate()
	players_container.add_child(local_player)
	local_player.position = Vector2(576, 324)
	local_player.setup(id, p_name, color, true)

func _cleanup_all_players() -> void:
	if local_player != null:
		local_player.queue_free()
		local_player = null
	for id in remote_players.keys():
		remote_players[id].queue_free()
	remote_players.clear()

func log_message(bbcode: String) -> void:
	if chat_log:
		chat_log.append_text(bbcode + "\n")
