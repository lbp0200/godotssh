use godot::prelude::*;
use std::sync::{Arc, Mutex};
use tokio::runtime::Runtime;
use russh::*;
use russh::client::*;
use crate::ssh_session::SSHSession;

// 客户端处理器 - 需要公开以便 SSHSession 使用
pub struct ClientHandler {
    #[allow(dead_code)] // password 在 Handler trait 的方法中使用，但编译器可能检测不到
    password: String,
}

#[async_trait::async_trait]
impl client::Handler for ClientHandler {
    type Error = russh::Error;

    async fn check_server_key(
        &mut self,
        _server_public_key: &russh_keys::key::PublicKey,
    ) -> Result<bool, Self::Error> {
        // 简单接受所有服务器密钥（生产环境应验证）
        Ok(true)
    }
}

#[derive(GodotClass)]
#[class(base=RefCounted)]
pub struct SSHClient {
    runtime: Arc<Mutex<Runtime>>,
    session: Arc<Mutex<Option<SSHSession>>>,
    connected: Arc<Mutex<bool>>,
    
    #[base]
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for SSHClient {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            runtime: Arc::new(Mutex::new(Runtime::new().unwrap())),
            session: Arc::new(Mutex::new(None)),
            connected: Arc::new(Mutex::new(false)),
            base,
        }
    }
}

#[godot_api]
impl SSHClient {
    /// 连接到 SSH 服务器
    #[func]
    pub fn connect_ssh(&mut self, host: String, port: i32, username: String, password: String) -> bool {
        let runtime = self.runtime.clone();
        let session = self.session.clone();
        let connected = self.connected.clone();
        
        let rt = runtime.lock().unwrap();
        let handle = rt.handle().clone();
        
        // 异步执行连接
        let result = handle.block_on(async move {
            match Self::connect_async(host, port, username, password).await {
                Ok(new_session) => {
                    *session.lock().unwrap() = Some(new_session);
                    *connected.lock().unwrap() = true;
                    Ok(true)
                }
                Err(e) => {
                    godot_error!("SSH 连接失败: {:?}", e);
                    Err(e)
                }
            }
        });
        
        drop(rt);
        result.unwrap_or(false)
    }
    
    /// 异步连接实现
    async fn connect_async(
        host: String,
        port: i32,
        username: String,
        password: String,
    ) -> Result<SSHSession, Box<dyn std::error::Error>> {
        let config = Arc::new(Config::default());
        let handler = ClientHandler { password: password.clone() };
        
        // connect 返回 Handle<Handler>
        let mut handle = match russh::client::connect(config, (host.as_str(), port as u16), handler).await {
            Ok(handle) => handle,
            Err(e) => return Err(format!("连接失败: {:?}", e).into()),
        };
        
        // 密码认证
        match handle.authenticate_password(&username, &password).await {
                Ok(true) => {
                godot_print!("SSH 认证成功");
                // 直接使用 Handle 创建 SSHSession
                Ok(SSHSession::new(handle))
            }
            Ok(false) => Err("认证失败".into()),
            Err(e) => Err(format!("认证错误: {:?}", e).into()),
        }
    }
    
    /// 断开连接
    #[func]
    pub fn disconnect(&mut self) {
        let session = self.session.clone();
        let connected = self.connected.clone();
        
        let mut sess = session.lock().unwrap();
        if let Some(s) = sess.take() {
            drop(sess);
            
            // 关闭会话
            let rt = self.runtime.lock().unwrap();
            let handle = rt.handle().clone();
            handle.block_on(async move {
                s.close().await;
            });
        }
        
        *connected.lock().unwrap() = false;
        godot_print!("SSH 连接已断开");
    }
    
    /// 检查是否已连接
    #[func]
    pub fn is_connected(&self) -> bool {
        *self.connected.lock().unwrap()
    }
    
    /// 执行命令并返回输出
    #[func]
    pub fn execute_command(&mut self, command: String) -> String {
        if !self.is_connected() {
            return "未连接".to_string();
        }
        
        let session = self.session.clone();
        let rt = self.runtime.lock().unwrap();
        let handle = rt.handle().clone();
        
        handle.block_on(async move {
            let sess = session.lock().unwrap();
            if let Some(ref s) = sess.as_ref() {
                match s.execute_command(command).await {
                    Ok(output) => output,
                    Err(e) => format!("执行错误: {:?}", e),
                }
            } else {
                "会话不存在".to_string()
            }
        })
    }
    
    /// 发送文本（用于交互式会话）
    #[func]
    pub fn send_text(&mut self, text: String) -> bool {
        if !self.is_connected() {
            return false;
        }
        
        let session = self.session.clone();
        let rt = self.runtime.lock().unwrap();
        let handle = rt.handle().clone();
        
        handle.block_on(async move {
            let sess = session.lock().unwrap();
            if let Some(ref s) = sess.as_ref() {
                s.send_text(text).await.is_ok()
            } else {
                false
            }
        })
    }
    
    /// 读取输出（非阻塞）
    #[func]
    pub fn read_output(&mut self) -> String {
        if !self.is_connected() {
            return String::new();
        }
        
        let session = self.session.clone();
        let rt = self.runtime.lock().unwrap();
        let handle = rt.handle().clone();
        
        handle.block_on(async move {
            let sess = session.lock().unwrap();
            if let Some(ref s) = sess.as_ref() {
                s.read_output().await
            } else {
                String::new()
            }
        })
    }
}

