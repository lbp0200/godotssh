use godot::prelude::*;

mod ssh_client;
mod ssh_session;

// SSHClient 由 godot-rust 自动注册，不需要显式导入

// GDExtension 初始化函数
#[gdextension]
unsafe impl ExtensionLibrary for SSHExtension {}

struct SSHExtension;

