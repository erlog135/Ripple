extends Node

const TYPE_SEQUENCE = 1
const TYPE_BG_COLOR = 2
const TYPE_CLIP_MODE = 3

var tcp_server := TCPServer.new()
var sockets: Array[WebSocketPeer] = []
var active_port: int = 0
signal server_status_changed(is_running: bool, ip: PackedStringArray, port: int)


func start_server(target_port: int = 12199):
	if tcp_server.is_listening():
		return
		
	var err = tcp_server.listen(target_port)

	# The Safety Net: Only try 10 random ports before giving up
	var max_retries = 10
	var attempts = 0

	while err != OK and attempts < max_retries:
		target_port = randi_range(49152, 65535)
		err = tcp_server.listen(target_port)
		attempts += 1
		
	# Evaluate the final result
	if err == OK:
		active_port = target_port
		server_status_changed.emit(true,IP.get_local_addresses(),active_port)
	else:
		active_port = 0
		printerr("Error binding port: ",error_string(err))
		server_status_changed.emit(false,PackedStringArray([]),-1)

func stop_server():
	tcp_server.stop()
	sockets.clear()
	active_port = 0
	server_status_changed.emit(false,PackedStringArray([]), 0)

func _process(_delta):
	if not tcp_server.is_listening():
		return
	
	# Network polling must happen every frame
	if tcp_server.is_connection_available():
		print_debug("new connection")
		var peer = tcp_server.take_connection()
		var ws = WebSocketPeer.new()
		ws.accept_stream(peer)
		sockets.append(ws)
		
	for ws in sockets:
		ws.poll()

func send_current_preview():
	if not tcp_server.is_listening() or sockets.is_empty():
		return
	
	var sequence: DrawCommandSequence = ProjectData.get_current_sequence()
	var seq_bytes = Fileman.sequence_to_pdc_bytes(sequence)
	
	seq_bytes.insert(0,TYPE_SEQUENCE)
	
	for sock in sockets:
		sock.send(seq_bytes)
