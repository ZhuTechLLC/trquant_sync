#!/usr/bin/env python3
"""
Ubuntu 端连接测试脚本
用于测试与 Windows 端 BulletTrade Server 的连接
"""

import os
import sys
import socket
from pathlib import Path

# 颜色输出
class Colors:
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def print_success(msg):
    print(f"{Colors.GREEN}✓ {msg}{Colors.NC}")

def print_error(msg):
    print(f"{Colors.RED}✗ {msg}{Colors.NC}")

def print_info(msg):
    print(f"{Colors.BLUE}ℹ {msg}{Colors.NC}")

def print_warning(msg):
    print(f"{Colors.YELLOW}⚠ {msg}{Colors.NC}")

def test_network_connection(host, port, timeout=5):
    """测试网络连接"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except Exception as e:
        print_error(f"连接测试异常: {e}")
        return False

def test_bullettrade_import():
    """测试 bullet-trade 是否已安装"""
    try:
        import bullet_trade
        print_success(f"bullet-trade 已安装: {bullet_trade.__version__ if hasattr(bullet_trade, '__version__') else '未知版本'}")
        return True
    except ImportError:
        print_error("bullet-trade 未安装")
        print_info("安装命令: pip install bullet-trade")
        return False

def test_env_config():
    """测试环境变量配置"""
    host = os.getenv('QMT_SERVER_HOST')
    port = os.getenv('QMT_SERVER_PORT', '58620')
    token = os.getenv('QMT_SERVER_TOKEN')
    
    print("\n环境变量配置:")
    if host:
        print_success(f"QMT_SERVER_HOST: {host}")
    else:
        print_warning("QMT_SERVER_HOST 未设置")
    
    print_info(f"QMT_SERVER_PORT: {port}")
    
    if token:
        print_success(f"QMT_SERVER_TOKEN: {'*' * len(token)}")
    else:
        print_warning("QMT_SERVER_TOKEN 未设置（如果 Windows 端设置了 token，这里也需要设置）")
    
    return host, port, token

def test_env_file():
    """测试 .env 文件"""
    env_file = Path('.env')
    if env_file.exists():
        print_success(f".env 文件存在: {env_file.absolute()}")
        
        # 读取并显示配置
        with open(env_file, 'r') as f:
            content = f.read()
            print("\n.env 文件内容:")
            for line in content.split('\n'):
                if line.strip() and not line.strip().startswith('#'):
                    # 隐藏 token
                    if 'TOKEN' in line:
                        key, _ = line.split('=', 1) if '=' in line else (line, '')
                        print(f"  {key}=***")
                    else:
                        print(f"  {line}")
        return True
    else:
        print_warning(".env 文件不存在")
        print_info("可以创建 .env 文件，内容示例:")
        print("  QMT_SERVER_HOST=你的Windows机器IP")
        print("  QMT_SERVER_PORT=58620")
        print("  QMT_SERVER_TOKEN=your_token  # 可选")
        return False

def main():
    print("=" * 50)
    print("BulletTrade Server 连接测试")
    print("=" * 50)
    print()
    
    # 测试 1: bullet-trade 安装
    print("[测试 1] 检查 bullet-trade 安装")
    if not test_bullettrade_import():
        sys.exit(1)
    print()
    
    # 测试 2: .env 文件
    print("[测试 2] 检查 .env 文件")
    has_env_file = test_env_file()
    print()
    
    # 测试 3: 环境变量
    print("[测试 3] 检查环境变量")
    host, port, token = test_env_config()
    print()
    
    # 测试 4: 网络连接
    if not host:
        print_error("无法测试网络连接: QMT_SERVER_HOST 未设置")
        print_info("请设置环境变量或创建 .env 文件")
        sys.exit(1)
    
    print(f"[测试 4] 测试网络连接: {host}:{port}")
    if test_network_connection(host, int(port)):
        print_success(f"网络连接成功: {host}:{port}")
    else:
        print_error(f"网络连接失败: {host}:{port}")
        print()
        print("排查建议:")
        print("  1. 确认 Windows 端 BulletTrade Server 正在运行")
        print("  2. 检查 Windows 防火墙是否开放端口", port)
        print("  3. 验证 IP 地址是否正确")
        print("  4. 测试命令: nc -zv", host, port)
        sys.exit(1)
    print()
    
    # 测试 5: 尝试导入 bullet_trade API
    print("[测试 5] 测试 bullet_trade API 导入")
    try:
        from bullet_trade.compat.api import *
        print_success("bullet_trade API 导入成功")
    except Exception as e:
        print_error(f"API 导入失败: {e}")
        sys.exit(1)
    print()
    
    print("=" * 50)
    print_success("所有测试通过！")
    print("=" * 50)
    print()
    print("下一步:")
    print("  1. 创建策略文件")
    print("  2. 运行回测: bullet-trade backtest strategy.py --start 2024-01-01 --end 2024-12-01")
    print("  3. 运行实盘: bullet-trade live strategy.py --broker qmt-remote")

if __name__ == '__main__':
    main()
