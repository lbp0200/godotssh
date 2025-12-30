#!/bin/bash

# SSH Extension 构建脚本
# 支持 macOS, Linux, Windows (使用 Git Bash 或 WSL)

set -e

echo "开始构建 SSH Extension..."

# 检测平台
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
    TARGET="debug"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    TARGET="debug"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    PLATFORM="windows"
    TARGET="debug"
else
    echo "未知平台: $OSTYPE"
    exit 1
fi

# 构建模式
MODE=${1:-debug}

if [ "$MODE" = "release" ]; then
    TARGET="release"
    CARGO_FLAGS="--release"
else
    TARGET="debug"
    CARGO_FLAGS=""
fi

echo "平台: $PLATFORM"
echo "模式: $TARGET"

# 构建 Rust 项目
cd "$(dirname "$0")"
cargo build $CARGO_FLAGS

echo "构建完成！"
echo "库文件位于: target/$TARGET/"

# 复制到项目目录（可选）
if [ "$PLATFORM" = "macos" ]; then
    LIB_NAME="libssh_extension.dylib"
elif [ "$PLATFORM" = "linux" ]; then
    LIB_NAME="libssh_extension.so"
elif [ "$PLATFORM" = "windows" ]; then
    LIB_NAME="ssh_extension.dll"
fi

echo "生成的库: target/$TARGET/$LIB_NAME"

