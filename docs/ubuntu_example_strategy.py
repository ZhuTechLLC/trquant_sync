#!/usr/bin/env python3
"""
Ubuntu 端示例策略
演示如何从 Ubuntu 连接到 Windows 端的 BulletTrade Server
"""

from bullet_trade.compat.api import *

def initialize(context):
    """
    初始化函数
    在策略启动时执行一次
    """
    # 设置基准
    set_benchmark('000300.XSHG')
    
    # 设置手续费和滑点
    set_order_cost(
        OrderCost(
            open_tax=0,
            close_tax=0.001,
            open_commission=0.0003,
            close_commission=0.0003,
            close_today_commission=0,
            min_commission=5
        ),
        type='stock'
    )
    
    # 设置滑点
    set_slippage(FixedSlippage(0.001))
    
    # 初始化全局变量
    g.security = '510300.XSHG'  # 沪深300ETF
    g.buy_amount = 10000  # 每次买入金额
    
    # 运行每日交易函数
    run_daily(trade, time='14:50')  # 收盘前10分钟执行
    
    log.info("策略初始化完成")
    log.info(f"目标股票: {g.security}")
    log.info(f"每次买入金额: {g.buy_amount}")

def before_trading_start(context):
    """
    盘前运行函数
    每个交易日开盘前执行
    """
    log.info("=" * 50)
    log.info(f"交易日: {context.current_dt}")
    log.info("=" * 50)
    
    # 获取账户信息
    portfolio = context.portfolio
    log.info(f"总资产: {portfolio.total_value:.2f}")
    log.info(f"可用资金: {portfolio.available_cash:.2f}")
    log.info(f"持仓数量: {len(portfolio.positions)}")

def trade(context):
    """
    交易函数
    根据策略逻辑执行交易
    """
    # 获取当前持仓
    current_position = context.portfolio.positions[g.security]
    
    # 获取当前价格
    current_data = get_current_data()
    current_price = current_data[g.security].last_price
    
    log.info(f"当前价格: {current_price:.2f}")
    log.info(f"当前持仓: {current_position.total_amount}")
    
    # 简单策略：如果没有持仓，买入
    if current_position.total_amount == 0:
        # 计算买入数量
        cash = context.portfolio.available_cash
        amount = min(g.buy_amount, cash * 0.9)  # 使用90%的可用资金
        shares = int(amount / current_price / 100) * 100  # 按手买入
        
        if shares > 0:
            log.info(f"买入信号: {g.security}, 数量: {shares}")
            order(g.security, shares)
        else:
            log.info("资金不足，无法买入")
    else:
        log.info("已有持仓，保持不动")

def after_trading_end(context):
    """
    盘后运行函数
    每个交易日收盘后执行
    """
    # 获取账户信息
    portfolio = context.portfolio
    log.info("=" * 50)
    log.info("收盘后账户信息:")
    log.info(f"总资产: {portfolio.total_value:.2f}")
    log.info(f"持仓市值: {portfolio.positions_value:.2f}")
    log.info(f"可用资金: {portfolio.available_cash:.2f}")
    
    # 显示持仓
    for security, position in portfolio.positions.items():
        if position.total_amount > 0:
            log.info(f"持仓: {security}, 数量: {position.total_amount}, "
                    f"成本: {position.avg_cost:.2f}, "
                    f"市值: {position.value:.2f}")
