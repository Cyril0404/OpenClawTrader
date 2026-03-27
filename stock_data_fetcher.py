#!/usr/bin/env python3
"""
股票数据获取脚本
用法: python3 stock_data_fetcher.py [股票代码]
输出: JSON格式股票数据
"""
import json
import sys
import os

# 使用venv中的库
VENV_PATH = os.path.join(os.path.dirname(__file__), "..", "daily_stock_analysis", ".venv", "lib", "python3.14", "site-packages")
sys.path.insert(0, VENV_PATH)

import efinance as ef

CODES = ["300548", "688037", "603986"]

def fetch_stock(code):
    try:
        df = ef.stock.get_latest_quote(code)
        if df is None or df.empty:
            return None
        row = df.iloc[0]
        return {
            "code": str(code),
            "name": str(row.get("名称", code)),
            "price": float(row.get("最新价", 0)),
            "change": float(row.get("涨跌幅", 0)),
            "high": float(row.get("最高", 0)),
            "low": float(row.get("最低", 0)),
            "turnover": float(row.get("换手率", 0)),
            "volume": float(row.get("成交额", 0)),
            "market": str(row.get("市场类型", "")),
            "updateTime": str(row.get("更新时间", "")),
        }
    except Exception as e:
        return {"code": code, "error": str(e)}

def main():
    if len(sys.argv) > 1:
        codes = sys.argv[1:]
    else:
        codes = CODES

    results = []
    for code in codes:
        data = fetch_stock(code)
        if data:
            results.append(data)

    print(json.dumps(results, ensure_ascii=False))

if __name__ == "__main__":
    main()
