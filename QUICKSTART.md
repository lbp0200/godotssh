# SSH Manager - 快速开始指南

## 概述

这是一个基于 Rust 和 Godot 的跨平台 SSH 客户端管理器。使用 `godot-rust` 和 `thrussh` 实现。

## 快速开始

### 1. 安装 Rust

```bash
# macOS/Linux
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Windows
# 下载并安装: https://rustup.rs/
```

### 2. 构建 SSH 扩展

```bash
cd ssh_extension
cargo build --release
```

### 3. 在 Godot 中配置

1. 打开 Godot 项目
2. 确保 `ssh_extension/godot-ssh.gdextension` 文件存在
3. 在 Godot 编辑器中，项目会自动检测并加载扩展

### 4. 使用示例

在 GDScript 中：

```gdscript
extends Node

var ssh_client: SSHClient

func _ready():
    ssh_client = SSHClient.new()

func connect_to_server():
    var success = ssh_client.connect_ssh("example.com", 22, "username", "password")
    if success:
        print("连接成功!")
        # 执行命令
        var result = ssh_client.execute_command("ls -la")
        print(result)
    else:
        print("连接失败")

func disconnect_from_server():
    ssh_client.disconnect()
```

## 目录结构

```
ssh-manager/
├── main.gd              # 主脚本（已更新为使用 Rust 扩展）
├── main.tscn            # 场景文件
├── ssh_extension/       # Rust 扩展
│   ├── Cargo.toml       # Rust 项目配置
│   ├── src/             # Rust 源码
│   │   ├── lib.rs       # 入口文件
│   │   ├── ssh_client.rs # SSH 客户端实现
│   │   └── ssh_session.rs # SSH 会话管理
│   ├── godot-ssh.gdextension # GDExtension 配置
│   └── README.md        # 详细文档
└── QUICKSTART.md        # 本文档
```

## 注意事项

⚠️ **首次构建可能需要较长时间**（下载依赖和编译）

⚠️ **确保库文件路径正确**：编译后的库文件应该在 `ssh_extension/target/release/` 目录下

⚠️ **平台特定的库文件名**：
- macOS: `libssh_extension.dylib`
- Linux: `libssh_extension.so`
- Windows: `ssh_extension.dll`

## 故障排除

### 扩展未加载

1. 检查 `godot-ssh.gdextension` 文件路径是否正确
2. 确认库文件已编译到指定目录
3. 查看 Godot 控制台的错误信息

### 编译错误

1. 确保 Rust 工具链已正确安装：`rustc --version`
2. 更新依赖：`cargo update`
3. 清理并重新构建：`cargo clean && cargo build`

### 运行时错误

1. 检查 SSH 服务器地址和端口
2. 确认用户名和密码正确
3. 查看 Godot 控制台的详细错误信息

## 下一步

- 查看 `ssh_extension/README.md` 了解详细 API
- 阅读 `main.gd` 查看使用示例
- 根据需要扩展功能（密钥认证、SFTP 等）

