#!/usr/bin/env python3
"""每5分钟写入实时行情到JSON，App直接读取"""
import json, os, sys

VENV = os.path.join(os.path.dirname(__file__), "daily_stock_analysis", ".venv", "lib", "python3.14", "site-packages")
sys.path.insert(0, VENV)
import efinance as ef

OUT = os.path.join(os.path.dirname(__file__), "stock_data.json")
CODES = ["300548", "688037", "603986"]

def write():
    results = []
    for code in CODES:
        try:
            df = ef.stock.get_latest_quote(code)
            if df is None or df.empty: continue
            r = df.iloc[0]
            results.append({
                "code": code,
                "name": r.get("名称",""),
                "price": r.get("最新价",0),
                "change": r.get("涨跌幅",0),
                "high": r.get("最高",0),
                "low": r.get("最低",0),
                "turnover": r.get("换手率",0),
                "volume": r.get("成交额",0),
                "updateTime": r.get("更新时间",""),
            })
        except: pass
    with open(OUT, "w") as f:
        json.dump(results, f, ensure_ascii=False)
    print(f"写入成功: {len(results)}只股票")

write()
