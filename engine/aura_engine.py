#!/usr/bin/env python3
"""
AURA · Gold signal engine
=========================
AURA by ACE TECH · a product of ACE OPS · built by Ace Khan
Runs on GitHub Actions every 15 minutes (free). It:
  1. downloads closed gold candles (Twelve Data spot XAU/USD, or Yahoo futures shifted to spot),
  2. runs EXACTLY the same rules as the AURA TradingView indicator,
  3. sends NEW events to your phone (Telegram and/or ntfy),
  4. writes docs/data/state.json + signals.json for the GitHub Pages dashboard.

Pure Python standard library, so there's nothing to install.
Secrets (set in GitHub → Settings → Secrets and variables → Actions):
  TWELVEDATA_API_KEY   (recommended, free: true spot XAU/USD)
  TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID   (optional)
  NTFY_TOPIC           (optional, e.g. aura-signals-8f3k2)
"""
import json, math, os, sys, time, urllib.request, urllib.parse
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "docs", "data")
CONFIG_PATH = os.path.join(ROOT, "config.json")
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36"
TZ_SA, TZ_NY, TZ_LDN = ZoneInfo("Africa/Johannesburg"), ZoneInfo("America/New_York"), ZoneInfo("Europe/London")
TF_MIN = {"5min": 5, "15min": 15, "1h": 60, "1day": 1440}
TF_LABEL = {"5min": "M5", "15min": "M15", "1h": "H1", "1day": "D1"}

DEFAULTS = {
    "account": "cent", "balance": 6000, "timeframes": ["5min", "15min", "1day"], "tf_overrides": {}, "symbol_label": "XAUUSD",
    "ema_fast": 9, "ema_slow": 21, "ema_trend": 200, "use_trend": True, "confirm_candle": True,
    "atr_len": 14, "sl_atr_buffer": 0.3, "rr": 3.0, "max_sl_atr": 0,
    "exit_mode": "hold", "be_after_tp1": False, "rej_wick_pct": 60, "rej_min_atr": 0.8,
    "kelly_fraction": 0.25, "max_risk_pct": 2.0, "start_risk_pct": 1.0, "min_trades_kelly": 30,
    "session": "all", "late_entry_r": 0.25, "notify_warnings": True, "notify_milestones": True,
    "usdzar_fallback": 16.6, "news_pause_before": 30, "news_pause_after": 15, "news_warn_minutes": 75, "stats_spread": 0.35,
}

# ───────────────────────────── helpers ─────────────────────────────
def http_json(url, data=None, headers=None, timeout=20):
    h = {"User-Agent": UA, **(headers or {})}
    req = urllib.request.Request(url, data=data, headers=h)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())

def log(*a): print("[AURA]", *a, flush=True)

def load_json(path, default):
    try:
        with open(path) as f: return json.load(f)
    except Exception: return default

def r2(x, d=2): return None if x is None or (isinstance(x, float) and math.isnan(x)) else round(x, d)

# ───────────────────────────── data ────────────────────────────────
def fetch_twelvedata(tf, key):
    url = "https://api.twelvedata.com/time_series?" + urllib.parse.urlencode(
        {"symbol": "XAU/USD", "interval": tf, "outputsize": 5000, "timezone": "UTC", "order": "ASC", "apikey": key})
    j = http_json(url, timeout=30)
    if j.get("status") != "ok": raise RuntimeError(f"Twelve Data: {j.get('message', j)}")
    bars = []
    for v in j["values"]:
        fmt = "%Y-%m-%d %H:%M:%S" if " " in v["datetime"] else "%Y-%m-%d"
        t = datetime.strptime(v["datetime"], fmt).replace(tzinfo=timezone.utc)
        bars.append((t, float(v["open"]), float(v["high"]), float(v["low"]), float(v["close"])))
    bars.sort(key=lambda b: b[0])
    return bars, "Twelve Data · spot XAU/USD"

def fetch_yahoo(tf):
    interval, rng = {"5min": ("5m", "60d"), "15min": ("15m", "60d"), "1h": ("60m", "730d"), "1day": ("1d", "10y")}[tf]
    j = http_json(f"https://query1.finance.yahoo.com/v8/finance/chart/GC=F?interval={interval}&range={rng}", timeout=30)
    res = j["chart"]["result"][0]; q = res["indicators"]["quote"][0]
    bars = []
    for i, ts in enumerate(res["timestamp"]):
        o, h, l, c = q["open"][i], q["high"][i], q["low"][i], q["close"][i]
        if None in (o, h, l, c): continue
        bars.append((datetime.fromtimestamp(ts, timezone.utc), o, h, l, c))
    # shift futures to spot using a live spot quote (signals depend on relative moves, not the level)
    src = "Yahoo · gold futures (GC=F)"
    try:
        spot = http_json("https://api.gold-api.com/price/XAU")["price"]
        off = spot - bars[-1][4]
        if abs(off) < 150:
            bars = [(t, o + off, h + off, l + off, c + off) for t, o, h, l, c in bars]
            src += f" shifted {off:+.2f} to spot"
    except Exception as e:
        log("spot offset failed:", e); src += " (NOT shifted: levels may differ from HFM by ~$10-30)"
    return bars, src

def fetch_bars(tf):
    key = os.environ.get("TWELVEDATA_API_KEY", "").strip()
    if key:
        try: return fetch_twelvedata(tf, key)
        except Exception as e: log("Twelve Data failed, falling back to Yahoo:", e)
    return fetch_yahoo(tf)

def drop_open_bar(bars, tf, now):
    step = timedelta(minutes=TF_MIN[tf])
    return [b for b in bars if b[0] + step <= now]

def fetch_usdzar(fallback):
    try:
        return float(http_json("https://open.er-api.com/v6/latest/USD")["rates"]["ZAR"]), "open.er-api.com"
    except Exception:
        return fallback, "config fallback"

# ───────────────────────────── indicators (Pine-compatible) ─────────
def ema(src, n):
    out, a, prev = [math.nan] * len(src), 2 / (n + 1), None
    for i, x in enumerate(src):
        if prev is None:
            if i >= n - 1: prev = sum(src[i - n + 1:i + 1]) / n; out[i] = prev
        else:
            prev = a * x + (1 - a) * prev; out[i] = prev
    return out

def rma(src, n):
    out, prev = [math.nan] * len(src), None
    for i, x in enumerate(src):
        if prev is None:
            if i >= n - 1: prev = sum(src[i - n + 1:i + 1]) / n; out[i] = prev
        else:
            prev = (prev * (n - 1) + x) / n; out[i] = prev
    return out

def session_flags(t):
    ny, ld = t.astimezone(TZ_NY), t.astimezone(TZ_LDN)
    nm, lm = ny.hour * 60 + ny.minute, ld.hour * 60 + ld.minute
    return (8 * 60 <= nm < 12 * 60), (7 * 60 <= lm < 11 * 60 + 30), (12 * 60 <= nm < 17 * 60)

def session_name(t):
    ny = t.astimezone(TZ_NY); nm = ny.hour * 60 + ny.minute; wd = ny.weekday()  # Mon=0
    if wd == 5 or (wd == 4 and nm >= 17 * 60) or (wd == 6 and nm < 18 * 60) or (17 * 60 <= nm < 18 * 60):
        return "CLOSED", "Market closed"
    n, l, late = session_flags(t)
    if n: return "BEST", "New York open"
    if l: return "OK", "London session"
    if late: return "WEAK", "Late New York"
    return "QUIET", "Asia session"

# ───────────────────────────── lot sizing ───────────────────────────
def lot_calc(cfg, usdzar, sl_dist, risk_pct):
    acc = cfg["account"]
    acc_to_zar = 1.0 if acc == "zar" else (usdzar / 100 if acc == "cent" else usdzar)
    acc_ccy = {"cent": "USC", "zar": "ZAR", "usd": "USD"}[acc]
    balance_zar = cfg["balance"] * acc_to_zar
    contract = 1.0 if acc == "cent" else 100.0          # oz per 1.00 lot (cent lot = 1/100)
    loss_per_lot = sl_dist * contract * usdzar           # ZAR lost per 1.00 lot if SL hits
    risk_zar = balance_zar * risk_pct / 100
    lots = math.floor(risk_zar / loss_per_lot * 100 + 1e-9) / 100 if loss_per_lot > 0 else None
    min_lot_pct = 0.01 * loss_per_lot / balance_zar * 100 if balance_zar > 0 else None
    return dict(lots=lots, risk_zar=risk_zar, risk_acct=risk_zar / acc_to_zar, acct_ccy=acc_ccy,
                min_lot_pct=min_lot_pct, balance_zar=balance_zar)

# ───────────────────────────── the AURA engine ──────────────────────
def run_engine(bars, tf, cfg, usdzar):
    T = [b[0] for b in bars]; O = [b[1] for b in bars]; H = [b[2] for b in bars]; L = [b[3] for b in bars]; C = [b[4] for b in bars]
    n = len(bars); step = timedelta(minutes=TF_MIN[tf])
    ef, es, et = ema(C, cfg["ema_fast"]), ema(C, cfg["ema_slow"]), ema(C, cfg["ema_trend"])
    tr = [H[0] - L[0]] + [max(H[i] - L[i], abs(H[i] - C[i - 1]), abs(L[i] - C[i - 1])) for i in range(1, n)]
    atr = rma(tr, cfg["atr_len"])
    smart = cfg["exit_mode"] == "smart"

    pos = 0; entry = sl = risk = tp1 = tp2 = tp3 = None; t1 = t2 = False; rej = False; rej_lvl = None; warn_on = False
    nT = nW = 0; sumW = sumL = eqR = peak = maxdd = 0.0
    entry_info = {}; events = []; advice = "WAIT for a signal"

    def stats():
        wr = nW / nT if nT else None
        aw = sumW / nW if nW else None
        al = sumL / (nT - nW) if nT - nW else None
        pay = aw / al if aw and al else None
        k = wr - (1 - wr) / pay if pay else None
        ready = nT >= cfg["min_trades_kelly"] and k is not None
        no_edge = ready and k <= 0
        rp = (0.0 if no_edge else min(k * cfg["kelly_fraction"] * 100, cfg["max_risk_pct"])) if ready else cfg["start_risk_pct"]
        return dict(trades=nT, win_rate=wr, avg_win=aw, avg_loss=al, payoff=pay, kelly=k, kelly_ready=ready,
                    no_edge=no_edge, risk_pct=rp, total_r=eqR, expectancy=eqR / nT if nT else None, max_dd=maxdd)

    def ev(i, typ, **kw):
        events.append(dict(key=f"{tf}|{typ}|{T[i].isoformat()}", tf=tf, event=typ,
                           bar_close=(T[i] + step).isoformat(), price=r2(C[i]), **kw))

    start = max(cfg["ema_trend"], cfg["ema_slow"], cfg["atr_len"]) + 1
    for i in range(start, n):
        if any(math.isnan(x) for x in (ef[i], es[i], et[i], atr[i], ef[i - 1], es[i - 1])): continue
        close_px = None; why = ""
        # ---- manage open trade
        if pos:
            if pos == 1:
                if L[i] <= sl: close_px, why = sl, ("BE" if t1 and cfg["be_after_tp1"] else "SL")
                else:
                    if not t1 and tp1 is not None and H[i] >= tp1: t1 = True; cfg["notify_milestones"] and ev(i, "TP1", note="TP1 reached: trade is working, keep holding")
                    if not t2 and tp2 is not None and H[i] >= tp2: t2 = True; cfg["notify_milestones"] and ev(i, "TP2", note="TP2 reached: keep holding for the final target")
                    if H[i] >= tp3: close_px, why = tp3, "TP"
            else:
                if H[i] >= sl: close_px, why = sl, ("BE" if t1 and cfg["be_after_tp1"] else "SL")
                else:
                    if not t1 and tp1 is not None and L[i] <= tp1: t1 = True; cfg["notify_milestones"] and ev(i, "TP1", note="TP1 reached: trade is working, keep holding")
                    if not t2 and tp2 is not None and L[i] <= tp2: t2 = True; cfg["notify_milestones"] and ev(i, "TP2", note="TP2 reached: keep holding for the final target")
                    if L[i] <= tp3: close_px, why = tp3, "TP"
            if close_px is None:
                if cfg["be_after_tp1"] and t1: sl = entry
                rng = H[i] - L[i]
                bear_rej = rng > 0 and (H[i] - max(O[i], C[i])) / rng * 100 >= cfg["rej_wick_pct"] and rng >= cfg["rej_min_atr"] * atr[i]
                bull_rej = rng > 0 and (min(O[i], C[i]) - L[i]) / rng * 100 >= cfg["rej_wick_pct"] and rng >= cfg["rej_min_atr"] * atr[i]
                rej_conf = rej and (C[i] < rej_lvl if pos == 1 else C[i] > rej_lvl)
                broken = C[i] < es[i] if pos == 1 else C[i] > es[i]
                if rej_conf or broken:
                    if smart: close_px, why = C[i], "EXIT"
                    else:
                        advice = "HOLD (warning: rejection confirmed)" if rej_conf else "HOLD (warning: closed past slow EMA)"
                        if not warn_on and cfg["notify_warnings"]: ev(i, "WARNING", note=advice)
                        warn_on = True
                else:
                    warn_on = False
                    new_rej = bear_rej if pos == 1 else bull_rej
                    weak = C[i] < ef[i] if pos == 1 else C[i] > ef[i]
                    advice = "CAUTION: rejection candle, watch next close" if new_rej else ("HOLD: pullback inside trend" if weak else "HOLD: trend intact, let it run")
                rej = bear_rej if pos == 1 else bull_rej
                rej_lvl = L[i] if pos == 1 else H[i]
        # ---- signals
        cross_up = ef[i] > es[i] and ef[i - 1] <= es[i - 1]
        cross_dn = ef[i] < es[i] and ef[i - 1] >= es[i - 1]
        n_open, l_open, _ = session_flags(T[i])
        in_sess = True if cfg["session"] == "all" else (n_open if cfg["session"] == "ny" else (n_open or l_open))
        sl_long, sl_short = L[i] - atr[i] * cfg["sl_atr_buffer"], H[i] + atr[i] * cfg["sl_atr_buffer"]
        wideL = cfg["max_sl_atr"] > 0 and (C[i] - sl_long) > cfg["max_sl_atr"] * atr[i]
        wideS = cfg["max_sl_atr"] > 0 and (sl_short - C[i]) > cfg["max_sl_atr"] * atr[i]
        buy = cross_up and (not cfg["confirm_candle"] or C[i] > O[i]) and (not cfg["use_trend"] or C[i] > et[i]) and in_sess and not wideL
        sell = cross_dn and (not cfg["confirm_candle"] or C[i] < O[i]) and (not cfg["use_trend"] or C[i] < et[i]) and in_sess and not wideS
        if close_px is None and ((buy and pos == -1) or (sell and pos == 1)):
            close_px, why = C[i], "REV"
        # ---- record close
        if close_px is not None and pos:
            R = (close_px - entry) / risk * pos
            Rn = R - cfg["stats_spread"] / risk          # track record counts the spread (same as the MT5 EA)
            nT += 1
            if Rn > 0: nW += 1; sumW += Rn
            else: sumL += -Rn
            eqR += Rn; peak = max(peak, eqR); maxdd = max(maxdd, peak - eqR)
            names = {"TP": ("TP", "Final take profit hit"), "SL": ("SL", "Stop loss hit"), "BE": ("BE", "Closed at breakeven"),
                     "EXIT": ("EXIT", "Smart exit: close the trade now"), "REV": ("REVERSE", "Opposite signal: old trade invalidated, close it")}
            ev(i, names[why][0], r=r2(R), side="LONG" if pos == 1 else "SHORT", entry=r2(entry), note=names[why][1])
            advice = {"TP": "TARGET HIT: bank it, wait for next signal", "SL": "STOPPED OUT: normal, wait for next signal",
                      "BE": "Closed at breakeven", "EXIT": "SMART EXIT: closed early", "REV": "REVERSED: old trade invalidated"}[why]
            pos = 0
        # ---- new entry
        nd = 1 if buy else (-1 if sell else 0)
        if nd and pos == 0:
            e, s = C[i], (sl_long if nd == 1 else sl_short); rk = abs(e - s)
            if rk > 0:
                st = stats()
                pos, entry, sl, risk = nd, e, s, rk
                tp1 = e + nd * rk if cfg["rr"] > 1 else None
                tp2 = e + nd * rk * 2 if cfg["rr"] > 2 else None
                tp3 = e + nd * rk * cfg["rr"]
                t1 = t2 = rej = warn_on = False
                lc = lot_calc(cfg, usdzar, rk, st["risk_pct"])
                advice = "SIGNAL, but Kelly says NO EDGE: skip" if st["no_edge"] else "NEW TRADE: place SL and TP now, then HOLD"
                entry_info = dict(side="LONG" if nd == 1 else "SHORT", entry=r2(e), sl=r2(s), tp1=r2(tp1), tp2=r2(tp2), tp3=r2(tp3),
                                  sl_dist=r2(rk), lots=lc["lots"], risk_pct=r2(st["risk_pct"]), risk_zar=r2(lc["risk_zar"]),
                                  risk_acct=r2(lc["risk_acct"]), acct_ccy=lc["acct_ccy"], account=cfg["account"],
                                  min_lot_pct=r2(lc["min_lot_pct"], 1), no_edge=st["no_edge"], opened=(T[i] + step).isoformat())
                ev(i, "BUY" if nd == 1 else "SELL", note=advice, **entry_info)
    # ---- final snapshot
    st = stats()
    last = n - 1
    open_trade = None
    if pos:
        live_r = (C[last] - entry) / risk * pos
        bars_since = int(((T[last] + step) - datetime.fromisoformat(entry_info["opened"])) / step)
        fresh = bars_since <= 2 and -0.5 <= live_r <= cfg["late_entry_r"]
        open_trade = dict(entry_info, sl=r2(sl), tp1_hit=t1, tp2_hit=t2, live_r=r2(live_r), bars_open=bars_since,
                          still_enterable=fresh, advice=advice)
    lc_next = lot_calc(cfg, usdzar, (atr[last] or 0) * 1.3, st["risk_pct"])
    snapshot = dict(tf=tf, last_bar_close=(T[last] + step).isoformat(), last_price=r2(C[last]), atr=r2(atr[last]),
                    ema_fast=r2(ef[last]), ema_slow=r2(es[last]), ema_trend=r2(et[last]),
                    trend="UP" if C[last] > et[last] else "DOWN", position=open_trade, advice=advice if pos else ("NO EDGE on this timeframe: don't trade it" if st["no_edge"] else "WAIT for a signal"),
                    stats={k: (r2(v, 4) if isinstance(v, float) else v) for k, v in st.items()},
                    next_trade=dict(risk_pct=r2(st["risk_pct"]), risk_zar=r2(lc_next["risk_zar"]), risk_acct=r2(lc_next["risk_acct"]),
                                    typical_lots=lc_next["lots"], min_lot_pct=r2(lc_next["min_lot_pct"], 1)),
                    bars=n, from_=T[0].isoformat())
    return events, snapshot

# ───────────────────────────── news + live-engine status ───────────
def fetch_news():
    """This week's economic calendar (ForexFactory feed). Times converted to UTC."""
    try:
        req = urllib.request.Request("https://nfs.faireconomy.media/ff_calendar_thisweek.json", headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=20) as r: raw = json.loads(r.read().decode())
    except Exception as ex:
        log("news calendar failed:", ex); return []
    out = []
    for e in raw:
        if e.get("country") != "USD" or e.get("impact") not in ("High", "Medium"): continue
        try: t = datetime.fromisoformat(e["date"]).astimezone(timezone.utc)
        except Exception: continue
        out.append(dict(title=e.get("title", ""), impact=e["impact"], time=t.isoformat(),
                        forecast=e.get("forecast") or None, previous=e.get("previous") or None))
    out.sort(key=lambda x: x["time"])
    return out

def news_window(t, news, cfg):
    """High-impact news event whose pause window contains time t (UTC), else None."""
    for n in news:
        if n["impact"] != "High": continue
        nt = datetime.fromisoformat(n["time"])
        if nt - timedelta(minutes=cfg["news_pause_before"]) <= t <= nt + timedelta(minutes=cfg["news_pause_after"]): return n
    return None

def gold_hint(title):
    s = title.lower()
    inverse = any(k in s for k in ("unemployment", "jobless", "claims"))
    return ("higher → USD down → GOLD likely UP 🟢 · lower → GOLD likely DOWN 🔴" if inverse
            else "higher → USD up → GOLD likely DOWN 🔴 · lower → GOLD likely UP 🟢")

def live_engine_status():
    """The MT5 live engine posts a heartbeat to <topic>-hb every 5 min. Online = seen in the last 12 min."""
    topic = os.environ.get("NTFY_TOPIC", "").strip()
    if not topic: return {"online": False, "last_seen": None}
    try:
        req = urllib.request.Request(f"https://ntfy.sh/{topic}-hb/json?poll=1&since=12h", headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=15) as r: lines = r.read().decode().strip().splitlines()
        times = [json.loads(l).get("time") for l in lines if l.strip()]
        times = [t for t in times if t]
        if not times: return {"online": False, "last_seen": None}
        last = datetime.fromtimestamp(max(times), timezone.utc)
        return {"online": datetime.now(timezone.utc) - last <= timedelta(minutes=12), "last_seen": last.isoformat()}
    except Exception as ex:
        log("heartbeat check failed:", ex); return {"online": False, "last_seen": None}

# ───────────────────────────── notifications ────────────────────────
EMOJI = {"BUY": "🟢", "SELL": "🔴", "TP1": "✅", "TP2": "✅", "TP": "🎯", "SL": "🛑", "BE": "⚪", "EXIT": "🟡", "REVERSE": "🔄", "WARNING": "⚠️"}
NTFY_TAGS = {"NEWS": "calendar", "BUY": "green_circle", "SELL": "red_circle", "TP1": "white_check_mark", "TP2": "white_check_mark", "TP": "dart",
             "SL": "octagonal_sign", "BE": "white_circle", "EXIT": "yellow_circle", "REVERSE": "arrows_counterclockwise", "WARNING": "warning"}

def fmt_msg(e, cfg, snap, now):
    tfl = TF_LABEL[e["tf"]]
    close_t = datetime.fromisoformat(e["bar_close"]); mins = int((now - close_t).total_seconds() // 60)
    lines = [f"{EMOJI.get(e['event'], '•')} AURA · {e['event']} · {cfg['symbol_label']} {tfl}"]
    if e["event"] in ("BUY", "SELL"):
        unit = "cent lots" if e["account"] == "cent" else f"lots ({e['acct_ccy']} acc)"
        lots = "SKIP (Kelly: no edge)" if e.get("no_edge") else ("< 0.01, too small, SKIP" if not e["lots"] or e["lots"] < 0.01 else f"{e['lots']:.2f} {unit}")
        risk_acct = "" if e["acct_ccy"] == "ZAR" else f" = {e['risk_acct']:,.0f} {e['acct_ccy']}" if e["acct_ccy"] == "USC" else f" = ${e['risk_acct']:.2f}"
        lines += [f"Entry: {e['entry']}", f"SL: {e['sl']}  (${e['sl_dist']} away)",
                  f"TP1: {e['tp1']}  TP2: {e['tp2']}", f"Final TP ({cfg['rr']:g}R): {e['tp3']}",
                  f"Lot: {lots}", f"Risk: R{e['risk_zar']:.2f}{risk_acct} ({e['risk_pct']}%)"]
        pos = snap.get("position")
        if pos and pos.get("entry") == e["entry"]:
            lines.append(f"Now: {snap['last_price']} ({pos['live_r']:+.2f}R) · " + ("✅ still enterable" if pos["still_enterable"] else "❌ moved too far, DON'T chase"))
    elif e.get("r") is not None:
        lines.append(f"Result: {e['r']:+.2f}R")
    if e.get("note"): lines.append(e["note"])
    lines.append(f"Candle closed {close_t.astimezone(TZ_SA):%H:%M} SA ({mins} min ago)")
    if e.get("news_note"): lines.append(e["news_note"])
    lines.append("☁️ Cloud backup (your MT5 live engine is offline)")
    return "\n".join(lines)

def send_telegram(text):
    tok, chat = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip(), os.environ.get("TELEGRAM_CHAT_ID", "").strip()
    if not tok or not chat: return False
    try:
        http_json(f"https://api.telegram.org/bot{tok}/sendMessage",
                  data=json.dumps({"chat_id": chat, "text": text, "disable_web_page_preview": True}).encode(),
                  headers={"Content-Type": "application/json"}); return True
    except Exception as ex: log("Telegram failed:", ex); return False

def send_ntfy(text, event, url_click=None):
    topic = os.environ.get("NTFY_TOPIC", "").strip()
    if not topic: return False
    try:
        h = {"Title": f"AURA {event}", "Tags": NTFY_TAGS.get(event, "bell"),
             "Priority": "high" if event in ("BUY", "SELL", "EXIT", "REVERSE") else "default", "User-Agent": UA}
        if url_click: h["Click"] = url_click; h["Icon"] = url_click.rstrip("/") + "/icon-192.png"
        urllib.request.urlopen(urllib.request.Request(f"https://ntfy.sh/{topic}", data=text.encode(), headers=h), timeout=15); return True
    except Exception as ex: log("ntfy failed:", ex); return False

def notify(text, event):
    page = os.environ.get("PAGES_URL", "").strip() or None
    a, b = send_telegram(text), send_ntfy(text, event, page)
    return a or b

# ───────────────────────────── main ─────────────────────────────────
def main():
    cfg = {**DEFAULTS, **load_json(CONFIG_PATH, {})}
    os.makedirs(DATA_DIR, exist_ok=True)
    now = datetime.now(timezone.utc)
    sig_path, state_path = os.path.join(DATA_DIR, "signals.json"), os.path.join(DATA_DIR, "state.json")
    store = load_json(sig_path, {"events": [], "seen": []})
    first_run = not store["seen"]
    seen = set(store["seen"])

    if os.environ.get("ACE_TEST_NOTIFY") == "1":
        ok = notify("✅ AURA test: your phone notifications are working.\nYou'll get BUY/SELL, TP, SL and warnings here.", "TEST")
        log("test notification sent:", ok)

    sess_code, sess_label = session_name(now)
    usdzar, fx_src = fetch_usdzar(cfg["usdzar_fallback"])
    snaps, all_events, sources, sent = {}, [], {}, 0
    fresh_window = {"5min": timedelta(minutes=30), "15min": timedelta(minutes=90), "1h": timedelta(hours=3), "1day": timedelta(hours=30)}
    news = fetch_news()
    live = live_engine_status()
    if live["online"]: log("MT5 live engine is ONLINE: cloud alerts muted (dashboard still updated)")

    for tf in cfg["timeframes"]:
        try:
            bars, src = fetch_bars(tf)
        except Exception as ex:
            log(f"{tf}: data download failed: {ex}"); continue
        bars = drop_open_bar(bars, tf, now)
        tcfg = {**cfg, **(cfg.get("tf_overrides") or {}).get(tf, {})}
        if len(bars) < tcfg["ema_trend"] + 50: log(f"{tf}: not enough bars ({len(bars)})"); continue
        events, snap = run_engine(bars, tf, dict(tcfg), usdzar)
        snaps[tf] = snap; sources[tf] = src
        for e in events:
            all_events.append(e)
            if e["key"] in seen: continue
            seen.add(e["key"])
            age = now - datetime.fromisoformat(e["bar_close"])
            if not first_run and age <= fresh_window[tf] and not live["online"]:
                nw = news_window(datetime.fromisoformat(e["bar_close"]), news, cfg) if e["event"] in ("BUY", "SELL") and tf != "1day" else None
                if nw: e["news_note"] = f"⏸ NEWS WINDOW ({nw['title']}): skip this entry, spreads/slippage too big"
                if notify(fmt_msg(e, tcfg, snap, now), e["event"]): sent += 1
                e["notified"] = now.isoformat()
        log(f"{tf}: {len(bars)} bars via {src} · last {snap['last_price']} · trades {snap['stats']['trades']} · pos {snap['position']['side'] if snap['position'] else 'FLAT'}")

    if first_run and snaps:
        notify(f"✅ AURA engine connected.\nWatching {cfg['symbol_label']} on {', '.join(TF_LABEL[t] for t in snaps)}.\nAccount: HFM {cfg['account'].upper()} · balance {cfg['balance']:,}.\nYou'll be notified of new signals from now on.\nAURA by ACE TECH · a product of ACE OPS · built by Ace Khan", "TEST")

    # backup news warnings (only when the MT5 live engine is offline)
    for n in news:
        if n["impact"] != "High": continue
        nt = datetime.fromisoformat(n["time"]); left = nt - now
        key = f"news|{n['title']}|{n['time']}"
        if timedelta(0) < left <= timedelta(minutes=cfg["news_warn_minutes"]) and key not in seen:
            seen.add(key)
            if live["online"] or first_run: continue
            msg = (f"📅 AURA NEWS in {int(left.total_seconds() // 60)} min\nUSD · {n['title']} (HIGH impact)\n"
                   f"Time: {nt.astimezone(TZ_SA):%H:%M} SA\n"
                   + (f"Forecast {n['forecast']}" + (f" · Previous {n['previous']}" if n['previous'] else "") + "\n" if n["forecast"] else "No forecast number\n")
                   + f"Actual vs forecast: {gold_hint(n['title'])}\n"
                   f"Don't open new trades {cfg['news_pause_before']} min before to {cfg['news_pause_after']} min after. Bank profit or move SL to entry on open trades.\n"
                   "☁️ Cloud backup: start MT5 + AURA EA for real-time news alerts and the breakout plan.")
            if notify(msg, "NEWS"): sent += 1

    # merge event history (newest first), keep last 300 for the dashboard
    merged = {e["key"]: e for e in store["events"]}
    for e in all_events: merged.setdefault(e["key"], e)
    events_out = sorted(merged.values(), key=lambda e: e["bar_close"], reverse=True)[:300]
    store_new = {"events": events_out, "seen": sorted(seen)[-5000:]}

    state = {"generated": now.isoformat(), "session": {"code": sess_code, "label": sess_label},
             "usdzar": r2(usdzar, 4), "usdzar_source": fx_src, "sources": sources,
             "config": {k: cfg[k] for k in ("account", "balance", "timeframes", "rr", "exit_mode", "kelly_fraction", "max_risk_pct", "session", "symbol_label")},
             "tf_settings": {tf: {k: {**cfg, **(cfg.get("tf_overrides") or {}).get(tf, {})}[k] for k in ("ema_fast", "ema_slow", "ema_trend", "rr")} for tf in cfg["timeframes"]},
             "news": [n for n in news if datetime.fromisoformat(n["time"]) >= now - timedelta(hours=2)][:30],
             "live_engine": live,
             "timeframes": snaps}

    # only rewrite files when something meaningful changed, or hourly (keeps the repo history small)
    old_state = load_json(state_path, {})
    def core(s): return json.dumps({tf: {k: v for k, v in (s.get("timeframes", {}).get(tf) or {}).items() if k in ("position", "advice", "stats", "trend")} for tf in cfg["timeframes"]}, sort_keys=True)
    old_gen = old_state.get("generated")
    stale = not old_gen or (now - datetime.fromisoformat(old_gen)) > timedelta(minutes=55)
    events_changed = store_new["events"] != store["events"] or store_new["seen"] != store["seen"]
    live_changed = (old_state.get("live_engine") or {}).get("online") != live["online"]
    if events_changed or stale or live_changed or core(state) != core(old_state):
        with open(state_path, "w") as f: json.dump(state, f, indent=1)
        with open(sig_path, "w") as f: json.dump(store_new, f, indent=1)
        log("data files updated")
    else:
        log("no changes, files left untouched")
    log(f"done · notifications sent: {sent} · session: {sess_label} · USD/ZAR {usdzar:.4f}")

if __name__ == "__main__":
    main()
