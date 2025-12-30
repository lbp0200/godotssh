extends Node

# UI 节点引用
@onready var host_input: LineEdit = $UI/H1
@onready var port_input: LineEdit = $UI/H2
@onready var user_input: LineEdit = $UI/H3
@onready var pass_input: LineEdit = $UI/H4
@onready var connect_btn: Button = $UI/ConnectBtn
@onready var disconnect_btn: Button = $UI/DisconnectBtn
@onready var output: TextEdit = $UI/Output

# SSH 客户端（使用 Rust 扩展）
var ssh_client: SSHClient = null

func _ready() -> void:
	connect_btn.pressed.connect(_on_connect)
	disconnect_btn.pressed.connect(_on_disconnect)
	port_input.text = "22"
	
	# 初始化 SSH 客户端
	ssh_client = SSHClient.new()
	_append_output("[信息] SSH 扩展已加载")

func _on_connect() -> void:
	if ssh_client == null:
		_append_output("[错误] SSH 客户端未初始化")
		return
	
	if ssh_client.is_connected():
		_append_output("[警告] 已经连接，请先断开")
		return
	
	var host = host_input.text.strip_edges()
	var port = int(port_input.text.strip_edges())
	var user = user_input.text.strip_edges()
	var password = pass_input.text
	
	if host.is_empty() or user.is_empty() or password.is_empty():
		_append_output("[错误] 请填写完整信息")
		return
	
	_append_output("[信息] 正在连接 %s@%s:%d ..." % [user, host, port])
	
	# 使用 Rust 扩展连接
	var success = ssh_client.connect_ssh(host, port, user, password)
	
	if success:
		_append_output("[成功] SSH 连接已建立")
		_update_ui_state(true)
	else:
		_append_output("[错误] SSH 连接失败")
		_update_ui_state(false)

func _on_disconnect() -> void:
	if ssh_client == null or not ssh_client.is_connected():
		return
	
	ssh_client.disconnect()
	_append_output("[信息] 已断开连接")
	_update_ui_state(false)

func _append_output(text: String) -> void:
	output.text += text + "\n"
	output.scroll_vertical = output.get_line_count()

func _update_ui_state(is_connected: bool) -> void:
	connect_btn.disabled = is_connected
	disconnect_btn.disabled = not is_connected
	
	# 可以在这里添加执行测试命令的功能
	if is_connected:
		_append_output("[提示] 可以使用 execute_command() 执行命令")

func _exit_tree() -> void:
	_on_disconnect()
