#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Export a compact intraday bundle via xtquant.xtdata (Windows/QMT runtime).

This script is intended to be called by `scripts/windows_ops_agent.ps1`.
It writes a JSON artifact containing:
- full_tick snapshot (best-effort)
- intraday 1m bars (best-effort)

Example:
  .\.venv\Scripts\python.exe scripts\xtdata_export_intraday.py --symbol 301005.SZ --period 1m --count 260 --out ops\artifacts\xt.json
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional


def _now_ts() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def _safe_write(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2, default=str), encoding="utf-8")
    tmp.replace(path)


def _try_full_tick(xtdata, symbol: str) -> Dict[str, Any]:
    out: Dict[str, Any] = {"ok": False, "symbol": symbol, "data": None, "error": None}
    try:
        ft = xtdata.get_full_tick([symbol])
        out["data"] = ft
        # Many versions return dict keyed by code like '301005.SZ'
        ok = isinstance(ft, dict) and bool(ft)
        out["ok"] = bool(ok)
        return out
    except Exception as exc:
        out["error"] = f"{type(exc).__name__}: {exc}"
        return out


def _try_1m_bars(xtdata, symbol: str, period: str, count: int, trade_date: str = "") -> Dict[str, Any]:
    out: Dict[str, Any] = {
        "ok": False,
        "symbol": symbol,
        "period": period,
        "count": int(count),
        "trade_date": trade_date or None,
        "rows": 0,
        "records": [],
        "head": [],
        "tail": [],
        "error": None,
    }

    try:
        import pandas as pd

        data = xtdata.get_market_data(stock_list=[symbol], period=period, count=int(count))
        df = None
        if isinstance(data, dict):
            df = data.get(symbol)
        if df is None:
            # Some versions use code without suffix
            key2 = symbol.split(".", 1)[0]
            if isinstance(data, dict):
                df = data.get(key2)
        if df is None or not isinstance(df, pd.DataFrame) or df.empty:
            out["ok"] = False
            out["rows"] = 0
            return out

        df2 = df.copy()
        try:
            df2.index = pd.to_datetime(df2.index)
        except Exception:
            pass

        if trade_date:
            # Filter by date (YYYY-MM-DD)
            try:
                df2 = df2[df2.index.strftime("%Y-%m-%d") == trade_date]
            except Exception:
                pass

        out["rows"] = int(df2.shape[0])
        out["ok"] = out["rows"] > 0
        if out["rows"] > 0:
            # Keep full records (bounded by count) for downstream analysis on Linux.
            # Convert index to an explicit time column.
            try:
                df_out = df2.copy()
                df_out = df_out.reset_index().rename(columns={df_out.index.name or "index": "time"})
                # Some xtdata returns columns like amount; keep all numeric columns.
                out["records"] = json.loads(df_out.to_json(orient="records", date_format="iso"))
            except Exception:
                out["records"] = []
            out["head"] = json.loads(df2.head(5).to_json(orient="records", date_format="iso"))
            out["tail"] = json.loads(df2.tail(5).to_json(orient="records", date_format="iso"))
        return out
    except Exception as exc:
        out["error"] = f"{type(exc).__name__}: {exc}"
        return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Export intraday xtdata bundle (Windows/QMT runtime)")
    ap.add_argument("--symbol", required=True, help="e.g. 301005.SZ")
    ap.add_argument("--period", default="1m", help="e.g. 1m")
    ap.add_argument("--count", type=int, default=260, help="recent bars count")
    ap.add_argument("--trade-date", default="", help="YYYY-MM-DD; if provided, filter bars to this date")
    ap.add_argument("--out", required=True, help="output json path")
    ap.add_argument("--no-full-tick", action="store_true", help="skip full tick export")
    args = ap.parse_args()

    out_path = Path(args.out)
    diag: Dict[str, Any] = {
        "ts": datetime.now().isoformat(timespec="seconds"),
        "symbol": str(args.symbol),
        "period": str(args.period),
        "count": int(args.count),
        "trade_date": args.trade_date or None,
        "full_tick": None,
        "bars": None,
        "error": None,
    }

    try:
        from xtquant import xtdata
    except Exception as exc:
        diag["error"] = f"xtquant_import_failed: {type(exc).__name__}: {exc}"
        _safe_write(out_path, diag)
        return 2

    if not args.no_full_tick:
        diag["full_tick"] = _try_full_tick(xtdata, str(args.symbol))

    diag["bars"] = _try_1m_bars(
        xtdata,
        symbol=str(args.symbol),
        period=str(args.period),
        count=int(args.count),
        trade_date=str(args.trade_date or ""),
    )

    _safe_write(out_path, diag)
    # Also print a tiny pointer for interactive runs
    print(json.dumps({"ok": True, "out": str(out_path), "ts": _now_ts()}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
