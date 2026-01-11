extends Control

# UI 节点引用
@onready var terminal: TextEdit = $TerminalContainer/TerminalOutput
@onready var status_left: Label = $TerminalContainer/StatusBar/StatusLeft
@onready var status_right: Label = $TerminalContainer/StatusBar/StatusRight
@onready var tab_button: Button = $TerminalContainer/TabBar/TabButton
@onready var ssh_tab_button: Button = $TerminalContainer/TabBar/SSHTabButton

# 终端状态
var current_dir: String = ""
var is_local_mode: bool = true
var command_history: Array[String] = []
var history_index: int = -1
var current_command: String = ""
var prompt_start_pos: int = 0  # 当前提示符的起始位置

# SSH 客户端（可选，通过 GDExtension 加载）
var ssh_client = null

func _ready() -> void:
	# 确保 Control 填充整个窗口
	call_deferred("_update_layout")
	
	# 连接信号
	terminal.text_changed.connect(_on_terminal_text_changed)
	terminal.gui_input.connect(_on_terminal_gui_input)
	tab_button.pressed.connect(_switch_to_local)
	ssh_tab_button.pressed.connect(_switch_to_ssh)
	
	# 确保所有文本控件都使用中文字体
	_ensure_fonts_loaded()
	
	# 初始化本地终端
	_initialize_local_terminal()
	
	# 显示欢迎信息
	_append_output("欢迎使用终端管理器")
	_append_output("当前模式: 本地终端")
	_append_output("")
	_show_prompt()

func _update_layout() -> void:
	# 强制更新布局，确保填充整个窗口
	var viewport_size = get_viewport_rect().size
	
	print("_update_layout 被调用，视口大小: ", viewport_size)
	
	# 确保 Main Control 填充窗口并居中
	if size != viewport_size:
		print("更新 Main Control 大小: ", size, " -> ", viewport_size)
		set_size(viewport_size)
	
	# 确保 Main Control 位置在 (0, 0)
	if position != Vector2.ZERO:
		set_position(Vector2.ZERO)
	
	# 确保 TerminalContainer 填充 Main Control
	var container = $TerminalContainer
	if container:
		if container.size != size:
			print("更新 TerminalContainer 大小: ", container.size, " -> ", size)
			container.set_size(size)
		
		# 确保 TerminalContainer 位置在 (0, 0)
		if container.position != Vector2.ZERO:
			print("更新 TerminalContainer 位置: ", container.position, " -> (0, 0)")
			container.set_position(Vector2.ZERO)
		
		# 确保 TerminalOutput 使用正确的 size_flags
		if terminal:
			# 移除任何最小尺寸限制
			terminal.custom_minimum_size = Vector2.ZERO
			terminal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			terminal.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			# 强制设置 TerminalOutput 的大小（如果布局系统没有正确工作）
			var tabbar = $TerminalContainer/TabBar
			var separator = $TerminalContainer/HSeparator
			var statusbar = $TerminalContainer/StatusBar
			
			var used_height = 0.0
			if tabbar:
				used_height += tabbar.size.y
			if separator:
				used_height += separator.size.y
			if statusbar:
				used_height += statusbar.custom_minimum_size.y
			
			var terminal_height = container.size.y - used_height
			var terminal_width = container.size.x
			
			# 确保 TerminalOutput 的宽度和高度都正确
			# 始终强制设置大小，确保充满整个容器
			if terminal_height > 0:
				if terminal.size.x != terminal_width or terminal.size.y != terminal_height:
					print("强制设置 TerminalOutput 大小: ", terminal.size, " -> (", terminal_width, ", ", terminal_height, ")")
					terminal.set_size(Vector2(terminal_width, terminal_height))
			
			# 确保 TerminalOutput 位置正确（应该在 TabBar 和 HSeparator 下方）
			var expected_y = 0.0
			if tabbar:
				expected_y += tabbar.size.y
			if separator:
				expected_y += separator.size.y
			
			if terminal.position != Vector2(0, expected_y):
				print("更新 TerminalOutput 位置: ", terminal.position, " -> (0, ", expected_y, ")")
				terminal.set_position(Vector2(0, expected_y))
		
		# 强制更新 TerminalContainer 的布局
		container.queue_sort()
	
	# 调试信息 - 打印各个控件的尺寸（延迟执行，让布局系统先更新）
	call_deferred("_print_layout_debug")

func _print_layout_debug() -> void:
	var viewport_size = get_viewport_rect().size
	print("=== 布局调试信息 ===")
	print("视口大小: ", viewport_size)
	print("Main Control 大小: ", size)
	print("Main Control 位置: ", position)
	if $TerminalContainer:
		print("TerminalContainer 大小: ", $TerminalContainer.size)
		print("TerminalContainer 位置: ", $TerminalContainer.position)
	if terminal:
		print("TerminalOutput 大小: ", terminal.size)
		print("TerminalOutput 位置: ", terminal.position)
		print("TerminalOutput size_flags_h: ", terminal.size_flags_horizontal)
		print("TerminalOutput size_flags_v: ", terminal.size_flags_vertical)
	print("==================")

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# 窗口大小改变时立即更新布局
		print("收到 NOTIFICATION_RESIZED 通知")
		_update_layout()
	elif what == NOTIFICATION_WM_SIZE_CHANGED:
		# Windows/macOS 窗口大小改变
		print("收到 NOTIFICATION_WM_SIZE_CHANGED 通知")
		call_deferred("_update_layout")


func _ensure_fonts_loaded() -> void:
	# 加载中文字体
	var font_file = load("res://NotoSerifSC-Regular.otf")
	if font_file:
		var font_variation = font_file.duplicate()
		if terminal:
			terminal.add_theme_font_override("font", font_variation)

func _initialize_local_terminal() -> void:
	is_local_mode = true
	# 获取当前工作目录
	var os_name = OS.get_name()
	
	if os_name == "Windows":
		current_dir = OS.get_environment("CD") if OS.has_environment("CD") else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	else:
		if OS.has_environment("PWD"):
			current_dir = OS.get_environment("PWD")
		else:
			current_dir = OS.get_environment("HOME") if OS.has_environment("HOME") else "/"
	
	# 验证目录是否存在
	var dir = DirAccess.open(current_dir)
	if not dir:
		current_dir = OS.get_environment("HOME") if OS.has_environment("HOME") else "/"
	
	status_left.text = "本地终端"
	
	# 初始化 SSH 客户端（可选）
	_try_init_ssh_client()

func _switch_to_local() -> void:
	is_local_mode = true
	status_left.text = "本地终端"
	tab_button.flat = false
	ssh_tab_button.flat = true
	_append_output("切换到本地终端模式")
	_show_prompt()

func _switch_to_ssh() -> void:
	is_local_mode = false
	status_left.text = "SSH 终端 (未连接)"
	tab_button.flat = true
	ssh_tab_button.flat = false
	_append_output("切换到 SSH 模式（需要先连接）")
	_show_prompt()

# 显示命令提示符
func _show_prompt() -> void:
	var prompt_text = _get_plain_prompt() + " $ "
	terminal.text += prompt_text
	current_command = ""
	prompt_start_pos = terminal.text.length()
	# 移动光标到提示符后
	terminal.set_caret_line(terminal.get_line_count() - 1)
	terminal.set_caret_column(prompt_text.length())
	# 确保光标可见
	terminal.scroll_vertical = terminal.get_line_count()
	# 聚焦到终端
	terminal.grab_focus()

# 获取纯文本版本的提示符
func _get_plain_prompt() -> String:
	if is_local_mode:
		var user = OS.get_environment("USER") if OS.has_environment("USER") else "user"
		var hostname = OS.get_environment("HOSTNAME") if OS.has_environment("HOSTNAME") else OS.get_name()
		var time_str = _get_current_time()
		
		var dir_display = current_dir
		var home = OS.get_environment("HOME") if OS.has_environment("HOME") else ""
		if not home.is_empty() and current_dir.begins_with(home):
			var remaining = current_dir.substr(home.length())
			if remaining == "":
				dir_display = "~"
			else:
				dir_display = "~" + remaining
		
		return time_str + " [ " + user + "@" + hostname + ":" + dir_display + " ]"
	else:
		return "SSH $ "

func _get_current_time() -> String:
	var time = Time.get_time_dict_from_system()
	var hour = time.hour
	var minute = time.minute
	var period = "上午" if hour < 12 else "下午"
	if hour > 12:
		hour -= 12
	elif hour == 0:
		hour = 12
	return "%d:%02d%s" % [hour, minute, period]

func _on_terminal_text_changed() -> void:
	# 获取最后一行（当前命令输入行）
	var last_line_index = terminal.get_line_count() - 1
	if last_line_index < 0:
		return
	
	var last_line = terminal.get_line(last_line_index)
	var prompt_text = _get_plain_prompt() + " $ "
	
	# 如果光标不在最后一行，移动到最后一行
	if terminal.get_caret_line() < last_line_index:
		terminal.set_caret_line(last_line_index)
		terminal.set_caret_column(last_line.length())
	
	# 确保最后一行以提示符开始
	if not last_line.begins_with(prompt_text):
		# 如果最后一行被修改了提示符，恢复它
		var new_line = prompt_text + current_command
		terminal.set_line(last_line_index, new_line)
		terminal.set_caret_line(last_line_index)
		# 使用当前行的长度，而不是整个文本的长度
		terminal.set_caret_column(new_line.length())
		prompt_start_pos = terminal.text.length() - current_command.length()
	else:
		# 更新当前命令
		current_command = last_line.substr(prompt_text.length())
		prompt_start_pos = terminal.text.length() - current_command.length()
		
		# 确保光标不会移动到提示符之前
		if terminal.get_caret_column() < prompt_text.length():
			terminal.set_caret_column(prompt_text.length())

func _on_terminal_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			# 执行命令
			_execute_current_command()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_UP:
			# 上箭头 - 历史记录
			if command_history.size() > 0:
				if history_index < 0:
					history_index = command_history.size() - 1
				else:
					history_index = max(0, history_index - 1)
				
				var prompt_text = _get_plain_prompt() + " $ "
				var last_line_index = terminal.get_line_count() - 1
				var old_line = terminal.get_line(last_line_index)
				if old_line.begins_with(prompt_text):
					var new_line = prompt_text + command_history[history_index]
					terminal.set_line(last_line_index, new_line)
					current_command = command_history[history_index]
					terminal.set_caret_line(last_line_index)
					terminal.set_caret_column(new_line.length())
					# 重新计算 prompt_start_pos
					var total_length = 0
					for i in range(last_line_index):
						total_length += terminal.get_line(i).length() + 1
					prompt_start_pos = total_length + prompt_text.length()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DOWN:
			# 下箭头 - 历史记录
			if command_history.size() > 0 and history_index >= 0:
				history_index += 1
				if history_index >= command_history.size():
					history_index = -1
					current_command = ""
				
				var prompt_text = _get_plain_prompt() + " $ "
				var last_line_index = terminal.get_line_count() - 1
				if history_index >= 0:
					var new_line = prompt_text + command_history[history_index]
					terminal.set_line(last_line_index, new_line)
					current_command = command_history[history_index]
				else:
					var new_line = prompt_text
					terminal.set_line(last_line_index, new_line)
					current_command = ""
				terminal.set_caret_line(last_line_index)
				terminal.set_caret_column(terminal.get_line(last_line_index).length())
				# 重新计算 prompt_start_pos
				var total_length = 0
				for i in range(last_line_index):
					total_length += terminal.get_line(i).length() + 1
				prompt_start_pos = total_length + prompt_text.length()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_BACKSPACE:
			# 防止删除提示符
			var last_line_index = terminal.get_line_count() - 1
			if terminal.get_caret_line() == last_line_index:
				var prompt_text = _get_plain_prompt() + " $ "
				if terminal.get_caret_column() <= prompt_text.length():
					get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_L:
			# Ctrl+L 清屏
			terminal.text = ""
			_show_prompt()
			get_viewport().set_input_as_handled()

func _execute_current_command() -> void:
	var cmd = current_command.strip_edges()
	
	# 清除历史索引
	history_index = -1
	
	# 处理特殊命令
	if cmd == "clear" or cmd == "cls":
		terminal.text = ""
		_show_prompt()
		return
	
	if cmd.is_empty():
		terminal.text += "\n"
		_show_prompt()
		return
	
	# 添加到历史记录
	if command_history.is_empty() or command_history[command_history.size() - 1] != cmd:
		command_history.append(cmd)
	
	# 执行命令
	terminal.text += "\n"
	
	if is_local_mode:
		_execute_local_command(cmd)
	else:
		_execute_ssh_command(cmd)
	
	_show_prompt()

func _execute_local_command(command: String) -> void:
	# 处理 cd 命令
	if command.begins_with("cd "):
		var path = command.substr(3).strip_edges()
		if path.is_empty():
			path = OS.get_environment("HOME") if OS.has_environment("HOME") else "/"
		elif path == "~":
			path = OS.get_environment("HOME") if OS.has_environment("HOME") else "/"
		elif path.begins_with("~/"):
			var home = OS.get_environment("HOME") if OS.has_environment("HOME") else ""
			if not home.is_empty():
				path = home + "/" + path.substr(2)
		
		var dir = DirAccess.open(current_dir)
		if dir:
			if dir.change_dir(path):
				current_dir = dir.get_current_dir()
			elif dir.change_dir(current_dir + "/" + path):
				current_dir = dir.get_current_dir()
			else:
				_append_output("cd: " + path + ": 没有那个文件或目录")
		return
	
	# 处理其他命令
	var os_name = OS.get_name()
	var shell_path = ""
	var shell_args: Array[String] = []
	
	if os_name == "Windows":
		shell_path = "cmd.exe"
		# Windows: 使用 /c 参数，并在命令前添加 cd
		var full_command = "cd /d \"" + current_dir + "\" && " + command
		shell_args = ["/c", full_command]
	else:
		# macOS/Linux: 使用 bash 而不是 sh，以支持更多 shell 特性（如大括号展开 {1..500}）
		# 检查 bash 是否存在，如果不存在则回退到 sh
		if FileAccess.file_exists("/bin/bash"):
			shell_path = "/bin/bash"
		else:
			shell_path = "/bin/sh"
		
		# 使用临时脚本文件来执行命令，避免引号转义问题
		# 这是最安全的方法，可以处理任何复杂的命令（包含引号、变量、特殊字符等）
		var temp_script = OS.get_cache_dir() + "/godot_terminal_script_" + str(Time.get_ticks_msec()) + ".sh"
		var file = FileAccess.open(temp_script, FileAccess.WRITE)
		if file:
			# 写入脚本：先 cd 到目录，然后执行命令
			file.store_string("cd '" + current_dir.replace("'", "'\\''") + "'\n")
			file.store_string(command + "\n")
			file.close()
			
			# 给脚本添加执行权限
			OS.execute("/bin/chmod", ["+x", temp_script], [], false)
			
			# 执行脚本
			shell_args = [temp_script]
		else:
			# 如果无法创建临时文件，回退到原来的方法（转义引号）
			var escaped_dir = current_dir.replace("'", "'\\''")
			var escaped_command = command.replace("'", "'\\''")
			var full_command = "cd '" + escaped_dir + "' && " + escaped_command
			shell_args = ["-c", full_command]
	
	var output: Array = []
	var exit_code: int = 0
	
	# OS.execute 的签名: execute(path, arguments, output, blocking, read_stdout)
	# path: shell 路径
	# arguments: 参数数组
	# output: 输出数组（通过引用传递，包含 stdout 和 stderr）
	# blocking=true: 阻塞执行直到完成
	# read_stdout=true: 读取标准输出（stderr 也会被包含在 output 中）
	exit_code = OS.execute(shell_path, shell_args, output, true, true)
	
	# 清理临时脚本文件（如果使用了）
	if os_name != "Windows" and shell_args.size() > 0:
		var temp_script = shell_args[0]
		if temp_script.begins_with(OS.get_cache_dir()):
			var dir = DirAccess.open(OS.get_cache_dir())
			if dir:
				dir.remove(temp_script.get_file())
	
	# 显示输出
	if output.size() > 0:
		for line in output:
			if not line.is_empty():
				_append_output(line)
	
	if exit_code != 0 and output.size() == 0:
		_append_output("命令执行失败，退出码: " + str(exit_code))

func _execute_ssh_command(command: String) -> void:
	# 尝试确保 SSH 客户端已初始化
	if not _ensure_ssh_client():
		_append_output("错误: SSH 扩展未加载或无法初始化")
		return
	
	if not ssh_client.has_method("is_connected") or not ssh_client.is_connected():
		_append_output("错误: 未连接到 SSH 服务器")
		return
	
	if ssh_client.has_method("execute_command"):
		var result = ssh_client.execute_command(command)
		if result.is_empty():
			_append_output("(无输出)")
		else:
			_append_output(result)
	else:
		_append_output("错误: SSH 客户端不支持命令执行")

func _append_output(text: String) -> void:
	terminal.text += text + "\n"
	# 自动滚动到底部
	terminal.scroll_vertical = terminal.get_line_count()

func _input(event: InputEvent) -> void:
	# 点击终端区域时聚焦
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if terminal.get_global_rect().has_point(event.global_position):
			terminal.grab_focus()
			# 移动光标到最后一行
			var last_line_idx = terminal.get_line_count() - 1
			terminal.set_caret_line(last_line_idx)
			# 使用最后一行的长度，而不是整个文本的长度
			var last_line = terminal.get_line(last_line_idx)
			terminal.set_caret_column(last_line.length())

func _try_init_ssh_client() -> void:
	# 尝试初始化 SSH 客户端（如果 GDExtension 可用）
	# 注意：SSHClient 类需要通过 GDExtension 加载
	# 
	# 在 GDScript 中，如果 GDExtension 类可用，可以直接使用 SSHClient.new()
	# 但由于 GDScript 没有 try-catch，如果类不存在会导致脚本错误
	# 所以我们延迟到实际需要时再创建（在切换到 SSH 模式或执行 SSH 命令时）
	# 
	# 这里先保持为 null，在实际使用时再尝试创建
	ssh_client = null

# 尝试创建 SSH 客户端实例（在实际需要时调用）
func _ensure_ssh_client() -> bool:
	if ssh_client != null:
		return true
	
	# 尝试创建 SSHClient 实例
	# 如果 GDExtension 已加载，SSHClient 类应该可用
	# 注意：如果类不存在，这会导致脚本错误
	# 在实际项目中，应该检查扩展是否已加载
	ssh_client = SSHClient.new()
	return ssh_client != null

func _exit_tree() -> void:
	if ssh_client != null and ssh_client.is_connected():
		ssh_client.disconnect()
