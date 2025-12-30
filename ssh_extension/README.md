# SSH Extension (Rust)

基于 Rust 和 `godot-rust` 实现的跨平台 SSH 客户端扩展。

## 特性

- ✅ 跨平台支持 (Windows、Linux、macOS)
- ✅ 密码认证
- ✅ 命令执行
- ✅ 异步操作（使用 tokio）
- ✅ 内存安全（Rust 保证）

## 构建要求

### 前置条件

1. **Rust 工具链** (1.70+)
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **Godot 4.3+** 已安装

3. **构建工具**:
   - macOS: Xcode Command Line Tools
   - Linux: `build-essential`, `pkg-config`, `libssl-dev`
   - Windows: MSVC Build Tools 或 Visual Studio

## 构建步骤

### 开发模式（Debug）

```bash
cd ssh_extension
./build.sh
# 或直接使用 cargo
cargo build
```

### 发布模式（Release）

```bash
cd ssh_extension
./build.sh release
# 或
cargo build --release
```

### Windows 构建

在 PowerShell 或 Git Bash 中：

```bash
cd ssh_extension
cargo build
# 或发布版本
cargo build --release
```

## 使用说明

### 1. 构建扩展库

首先构建 Rust 扩展：

```bash
cd ssh_extension
cargo build --release
```

### 2. 配置 GDExtension

确保 `godot-ssh.gdextension` 文件中的路径正确指向编译生成的库文件。

### 3. 在 Godot 中使用

在 GDScript 中：

```gdscript
var ssh_client = SSHClient.new()

# 连接
var success = ssh_client.connect_ssh("example.com", 22, "username", "password")
if success:
    print("连接成功")

# 执行命令
var output = ssh_client.execute_command("ls -la")
print(output)

# 断开连接
ssh_client.disconnect()
```

## API 参考

### SSHClient 类

#### `connect_ssh(host: String, port: i32, username: String, password: String) -> bool`
连接到 SSH 服务器。

#### `disconnect() -> void`
断开连接。

#### `is_connected() -> bool`
检查连接状态。

#### `execute_command(command: String) -> String`
执行命令并返回输出。

#### `send_text(text: String) -> bool`
发送文本到交互式会话（待实现）。

#### `read_output() -> String`
读取输出（待实现）。

## 故障排除

### 构建错误

1. **找不到 godot-rust**
   - 确保 `godot` crate 版本与你的 Godot 版本兼容
   - 运行 `cargo update`

2. **链接错误**
   - macOS: 确保 Xcode Command Line Tools 已安装
   - Linux: 安装 `libssl-dev`: `sudo apt install libssl-dev`
   - Windows: 确保 MSVC 工具链已安装

3. **运行时加载失败**
   - 检查 `.gdextension` 文件路径是否正确
   - 确保库文件与平台匹配
   - 检查 Godot 控制台的错误信息

## 开发计划

- [ ] 密钥认证支持
- [ ] 交互式 shell 支持
- [ ] SFTP 文件传输
- [ ] 端口转发
- [ ] 更多错误处理和日志

## 许可证

MIT License

