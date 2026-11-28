extends Node

## Find a ranked table on the same Wi-Fi, then open an ENet seat.
## Open search still matches the first other phone it hears.
## Play a Friend hosts or joins one exact table code.

signal found_peer(hosting: bool, peer_name: String)
signal search_pulse(code: String)

const MAGIC := "BROLIVE1"
const DISCOVER := 27171
const GAME := 27172
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var code := ""
var player_name := "Flicker"
var searching := false
var hosting := false
var mode := "open"
var peer_name := ""
var _udp: PacketPeerUDP
var _peer: ENetMultiplayerPeer
var _tick := 0.0


func start_search(display_name: String, room: String) -> void:
	_begin(display_name, room if room != "" else "LIVE", "open", true)


func start_host(display_name: String, room: String) -> void:
	_begin(display_name, room, "host", true)


func start_join(display_name: String, room: String) -> void:
	_begin(display_name, room, "join", false)


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


static func friend_room(a: String, b: String) -> String:
	var left := a.strip_edges().to_upper()
	var right := b.strip_edges().to_upper()
	if left > right:
		var swap := left
		left = right
		right = swap
	var key := "%s|%s" % [left, right]
	var h := 5381
	for i in key.length():
		h = int((h << 5) + h) + key.unicode_at(i)
		h = h & 0x7fffffff
	var out := ""
	var n := h
	for _i in 5:
		out += ALPHABET[n % ALPHABET.length()]
		n = int(n / ALPHABET.length())
	return out


static func first_name(a: String, b: String) -> bool:
	return a.strip_edges().to_upper() <= b.strip_edges().to_upper()


func _begin(display_name: String, room: String, next_mode: String, as_host: bool) -> void:
	close_table()
	player_name = display_name if display_name != "" else "Flicker"
	code = room.strip_edges().to_upper()
	if code == "":
		code = "LIVE"
	mode = next_mode
	searching = true
	hosting = as_host
	peer_name = ""
	_tick = 0.0
	_udp = PacketPeerUDP.new()
	var bind_err := _udp.bind(DISCOVER)
	if bind_err != OK:
		_udp.close()
		_udp = PacketPeerUDP.new()
		_udp.bind(DISCOVER)
	_udp.set_broadcast_enabled(true)
	if as_host:
		_peer = ENetMultiplayerPeer.new()
		var err := _peer.create_server(GAME, 1)
		if err != OK:
			hosting = false
			_peer = null
		else:
			multiplayer.multiplayer_peer = _peer
			_wire_peer()
	set_process(true)
	search_pulse.emit(code)


func _wire_peer() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)


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
	var kind := "OPEN"
	if mode == "host":
		kind = "HOST"
	elif mode == "join":
		kind = "LOOK"
	var payload := "%s|%s|%s|%s" % [MAGIC, kind, code, player_name]
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
		var kind := "OPEN"
		var their_code := ""
		var their_name := ""
		if bits.size() >= 4:
			kind = str(bits[1]).to_upper()
			their_code = str(bits[2]).to_upper()
			their_name = str(bits[3])
		else:
			their_code = str(bits[1]).to_upper()
			their_name = str(bits[2])
		_hear(ip, kind, their_code, their_name)


func _hear(ip: String, kind: String, their_code: String, their_name: String) -> void:
	if not searching:
		return
	if mode == "join":
		if kind == "HOST" and their_code == code:
			_join(ip, their_name)
		return
	if mode == "host":
		if kind == "LOOK" and their_code == code and their_name != "":
			peer_name = their_name
		if kind == "HOST" and their_code == code and their_name.to_upper() < player_name.to_upper():
			_join(ip, their_name)
		return
	if kind == "OPEN" or kind == "HOST":
		if their_code < code:
			_join(ip, their_name)
		elif their_code > code and their_name != "":
			peer_name = their_name


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
	_wire_peer()


func _on_peer_connected(_id: int) -> void:
	if not searching:
		return
	searching = false
	found_peer.emit(true, peer_name if peer_name != "" else "Friend")


func _on_connected() -> void:
	found_peer.emit(false, peer_name if peer_name != "" else "Friend")


func _is_self(ip: String) -> bool:
	if ip == "" or ip == "127.0.0.1" or ip == "0.0.0.0":
		return true
	for local in IP.get_local_addresses():
		if str(local) == ip:
			return true
	return false
