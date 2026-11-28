extends Node

## Worldwide club at bowl-roll-club.fly.dev. Names, invites, codes, and shot relay.

signal found_peer(hosting: bool, peer_name: String)
signal search_pulse(code: String)
signal club_shot(px: float, hx: float, hz: float, ax: float, az: float, power: float, bias: int, hand: float, jack: bool)
signal club_skip
signal club_peer_left
signal signed_in(player: String)
signal name_taken(player: String)
signal player_found(player: String, online: bool)
signal player_list(matches: Array)
signal player_missing(player: String)
signal invite_received(from_name: String, table: String, options: Dictionary)
signal invite_sent(to_name: String, table: String, options: Dictionary)
signal invite_failed(reason: String, player: String)

const CLUB_URL := "wss://bowl-roll-club.fly.dev/ws"
const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var code := ""
var player_name := "Flicker"
var searching := false
var hosting := false
var mode := "open"
var peer_name := ""
var matched := false
var signed := false
var _ws: WebSocketPeer
var _hello := false
var _join_retry := 0.0
var _pulse := 0.0
var _retry := 0.0
var _want := false
var _pending_find := ""
var _pending_to := ""
var _pending_opt := {}


func sign_in(display_name: String) -> void:
	player_name = display_name if display_name != "" else "Flicker"
	_want = true
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send({"type": "hello", "name": player_name})
		return
	_open()


func find_player(display_name: String) -> void:
	_pending_find = display_name
	_want = true
	_ensure()
	_flush_pending()


func invite_player(to_name: String, options: Dictionary) -> void:
	_pending_to = to_name
	_pending_opt = options
	_want = true
	_ensure()
	_flush_pending()


func start_search(display_name: String, room: String) -> void:
	_begin(display_name, room if room != "" else "LIVE", "open", true)


func start_host(display_name: String, room: String) -> void:
	_begin(display_name, room, "host", true)


func start_join(display_name: String, room: String) -> void:
	_begin(display_name, room, "join", false)


func stop_search() -> void:
	searching = false


func close_table() -> void:
	searching = false
	matched = false
	peer_name = ""
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_send({"type": "leave"})


func has_table() -> bool:
	return matched and _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN


func send_shot(px: float, hx: float, hz: float, ax: float, az: float, power: float, bias: int, hand: float, jack: bool) -> void:
	_send({
		"type": "relay",
		"payload": {
			"kind": "shot",
			"px": px,
			"hx": hx,
			"hz": hz,
			"ax": ax,
			"az": az,
			"power": power,
			"bias": bias,
			"hand": hand,
			"jack": jack,
		},
	})


func send_skip() -> void:
	_send({"type": "relay", "payload": {"kind": "skip"}})


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
	matched = false
	_join_retry = 0.0
	_pulse = 0.0
	_want = true
	_ensure()
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_greet()
	search_pulse.emit(code)


func _open() -> void:
	if _ws != null:
		var state := _ws.get_ready_state()
		if state == WebSocketPeer.STATE_CONNECTING or state == WebSocketPeer.STATE_OPEN:
			return
	_ws = WebSocketPeer.new()
	_hello = false
	var err := _ws.connect_to_url(CLUB_URL)
	if err != OK:
		_ws = null
		_retry = 1.6
		set_process(true)
		return
	set_process(true)


func _ensure() -> void:
	if _ws == null or _ws.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_open()


func _process(delta: float) -> void:
	if _ws == null:
		if _want:
			_retry -= delta
			if _retry <= 0.0:
				_retry = 2.4
				_open()
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _hello:
			_hello = true
			_send({"type": "hello", "name": player_name})
			if searching:
				_greet()
			_flush_pending()
		while _ws.get_available_packet_count() > 0:
			_read_packet()
		if searching:
			_pulse += delta
			if _pulse >= 0.8:
				_pulse = 0.0
				search_pulse.emit(code)
				if mode == "join" and not matched:
					_greet()
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_matched := matched
		_ws = null
		_hello = false
		signed = false
		if was_matched:
			matched = false
			club_peer_left.emit()
		if _want:
			_retry = 1.2
		else:
			set_process(false)


func _flush_pending() -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if _pending_find != "":
		_send({"type": "find", "name": _pending_find})
		_pending_find = ""
	if _pending_to != "":
		_send({"type": "invite", "to": _pending_to, "options": _pending_opt})
		_pending_to = ""
		_pending_opt = {}


func _greet() -> void:
	if mode == "host":
		_send({"type": "host", "code": code, "name": player_name})
	elif mode == "join":
		_send({"type": "join", "code": code, "name": player_name})
	else:
		_send({"type": "search", "name": player_name})


func _send(msg: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ws.send_text(JSON.stringify(msg))


func _read_packet() -> void:
	var text := _ws.get_packet().get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var msg: Dictionary = parsed
	var kind := str(msg.get("type", ""))
	if kind == "hello_ok":
		signed = true
		player_name = str(msg.get("name", player_name))
		signed_in.emit(player_name)
	elif kind == "name_taken":
		signed = false
		name_taken.emit(str(msg.get("name", player_name)))
	elif kind == "hosted":
		code = str(msg.get("code", code))
		search_pulse.emit(code)
	elif kind == "searching":
		search_pulse.emit(code)
	elif kind == "matched":
		_on_matched(msg)
	elif kind == "relay":
		_on_relay(msg)
	elif kind == "peer_left":
		club_peer_left.emit()
	elif kind == "found":
		player_found.emit(str(msg.get("name", "")), bool(msg.get("online", false)))
	elif kind == "found_list":
		var raw: Variant = msg.get("matches", [])
		var matches: Array = raw if typeof(raw) == TYPE_ARRAY else []
		player_list.emit(matches)
	elif kind == "not_found":
		player_missing.emit(str(msg.get("name", "")))
	elif kind == "invite":
		invite_received.emit(str(msg.get("from", "Friend")), str(msg.get("code", "")), _as_dict(msg.get("options", {})))
	elif kind == "invite_sent":
		code = str(msg.get("code", code))
		invite_sent.emit(str(msg.get("to", "")), code, _as_dict(msg.get("options", {})))
	elif kind == "invite_failed":
		invite_failed.emit(str(msg.get("error", "offline")), str(msg.get("name", "")))
	elif kind == "error":
		var err := str(msg.get("error", ""))
		if err == "no_table" and mode == "join" and searching:
			return
		if err == "offline":
			invite_failed.emit("offline", "")


func _on_matched(msg: Dictionary) -> void:
	var role := str(msg.get("role", ""))
	code = str(msg.get("code", code))
	peer_name = str(msg.get("peer", "Friend"))
	hosting = role == "host"
	matched = true
	searching = false
	found_peer.emit(hosting, peer_name if peer_name != "" else "Friend")


func _as_dict(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _on_relay(msg: Dictionary) -> void:
	var payload: Variant = msg.get("payload", {})
	if typeof(payload) != TYPE_DICTIONARY:
		return
	var body: Dictionary = payload
	var kind := str(body.get("kind", ""))
	if kind == "skip":
		club_skip.emit()
		return
	if kind != "shot":
		return
	club_shot.emit(
		float(body.get("px", 0.0)),
		float(body.get("hx", 0.0)),
		float(body.get("hz", 0.0)),
		float(body.get("ax", 0.0)),
		float(body.get("az", 0.0)),
		float(body.get("power", 0.0)),
		int(body.get("bias", 0)),
		float(body.get("hand", -1.0)),
		bool(body.get("jack", false))
	)
