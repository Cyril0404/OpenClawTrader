#!/usr/bin/env python3
"""
本地股票数据API服务
运行: python3 stock_api_server.py
访问: http://localhost:18420/stock
"""
import json
import os
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading

VENV_PATH = os.path.join(os.path.dirname(__file__), "daily_stock_analysis", ".venv", "lib", "python3.14", "site-packages")
sys.path.insert(0, VENV_PATH)

import efinance as ef

PORT = 18420
CODES = ["300548", "688037", "603986"]
_cache = None
_cache_time = 0
CACHE_TTL = 60  # 缓存60秒

def fetch_stocks():
    global _cache, _cache_time
    import time
    now = time.time()
    if _cache and (now - _cache_time) < CACHE_TTL:
        return _cache
    results = []
    for code in CODES:
        try:
            df = ef.stock.get_latest_quote(code)
            if df is None or df.empty:
                continue
            row = df.iloc[0]
            results.append({
                "code": str(code),
                "name": str(row.get("名称", code)),
                "price": float(row.get("最新价", 0)),
                "change": float(row.get("涨跌幅", 0)),
                "high": float(row.get("最高", 0)),
                "low": float(row.get("最低", 0)),
                "turnover": float(row.get("换手率", 0)),
                "volume": float(row.get("成交额", 0)),
                "updateTime": str(row.get("更新时间", "")),
            })
        except Exception as e:
            results.append({"code": code, "error": str(e)})
    _cache = results
    _cache_time = now
    return results

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass  # 静默日志

    def do_GET(self):
        if self.path in ["/stock", "/stocks", "/"]:
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            data = fetch_stocks()
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode())
        elif self.path.startswith("/stock/"):
            code = self.path[8:]
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            for item in fetch_stocks():
                if item.get("code") == code:
                    self.wfile.write(json.dumps(item, ensure_ascii=False).encode())
                    return
            self.wfile.write(json.dumps({"error": "not found"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

def main():
    server = HTTPServer(("localhost", PORT), Handler)
    print(f"✅ 股票API服务已启动: http://localhost:{PORT}/stock")
    server.serve_forever()

if __name__ == "__main__":
    main()
