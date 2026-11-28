extends Node

## Find a ranked table on the same Wi-Fi, then open an ENet seat.

signal found_peer(hosting: bool, peer_name: String)
signal search_pulse(code: String)

const MAGIC := "BROLIVE1"
const DISCOVER := 27171
const GAME := 27172

var code := ""
var player_name := "Flicker"
var searching := false
var hosting := false
var peer_name := ""
var _udp: PacketPeerUDP
var _peer: ENetMultiplayerPeer
var _tick := 0.0


func start_search(display_name: String, room: String) -> void:
	stop_search()
	player_name = display_name if display_name != "" else "Flicker"
	code = room if room != "" else "LIVE"
	searching = true
	hosting = true
	peer_name = ""
	_udp = PacketPeerUDP.new()
	var bind_err := _udp.bind(DISCOVER)
	if bind_err != OK:
		_udp.close()
		_udp = PacketPeerUDP.new()
	_udp.set_broadcast_enabled(true)
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(GAME, 1)
	if err != OK:
		hosting = false
		_peer = null
	else:
		multiplayer.multiplayer_peer = _peer
		if not multiplayer.peer_connected.is_connected(_on_peer_connected):
			multiplayer.peer_connected.connect(_on_peer_connected)
	set_process(true)
	search_pulse.emit(code)


func stop_search() -> void:
	searching = false
	set_process(false)
	if _udp != null:
		_udp.close()
		_udp = null


func close_table() -> void:
	stop_search()
	if _peer != null:
		_peer.close()
		_peer = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null


func _process(delta: float) -> void:
	if not searching:
		return
	_tick += delta
	if _tick >= 0.55:
		_tick = 0.0
		_broadcast()
		search_pulse.emit(code)
	_listen()


func _broadcast() -> void:
	if _udp == null:
		return
	var payload := "%s|%s|%s" % [MAGIC, code, player_name]
	_udp.set_dest_address("255.255.255.255", DISCOVER)
	_udp.put_packet(payload.to_utf8_buffer())


func _listen() -> void:
	if _udp == null:
		return
	while _udp.get_available_packet_count() > 0:
		var raw := _udp.get_packet()
		var ip := _udp.get_packet_ip()
		if _is_self(ip):
			continue
		var text := raw.get_string_from_utf8()
		var bits := text.split("|")
		if bits.size() < 3 or bits[0] != MAGIC:
			continue
		var their_code := str(bits[1])
		if their_code < code:
			_join(ip, str(bits[2]))


func _join(ip: String, other_name: String) -> void:
	if not searching or ip == "":
		return
	searching = false
	hosting = false
	peer_name = other_name
	if _peer != null:
		_peer.close()
		_peer = null
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, GAME)
	if err != OK:
		searching = true
		return
	multiplayer.multiplayer_peer = _peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)


func _on_peer_connected(_id: int) -> void:
	if not searching:
		return
	searching = false
	found_peer.emit(true, peer_name if peer_name != "" else "Opponent")


func _on_connected() -> void:
	found_peer.emit(false, peer_name if peer_name != "" else "Opponent")


func _is_self(ip: String) -> bool:
	if ip == "" or ip == "127.0.0.1" or ip == "0.0.0.0":
		return true
	for local in IP.get_local_addresses():
		if str(local) == ip:
			return true
	return false
