# AURA · Gold Signals (100% free)

**AURA by ACE TECH** · a product of **ACE OPS** · built by **Ace Khan**

| | Your live links |
|---|---|
| 📱 App | https://waizyk.github.io/aura/ |
| ⚙️ Settings | [`config.json`](config.json) |
| ▶ Run / test | Actions → **AURA signals** → Run workflow |


## Two engines, one app

| | ⚡ **MT5 live engine** (main) | ☁️ **Cloud backup** (this repo) |
|---|---|---|
| Runs on | Your Windows PC, inside HFM MT5 | GitHub Actions, free |
| Prices | **HFM's own live feed** | Twelve Data / Yahoo |
| Speed | **Real time**: first tick after the candle closes; SL/TP on the tick | Every ~15 min, often a few minutes late |
| Timeframes | M5 · M15 · D1 | M5 · M15 · D1 (dashboard), alerts only when the PC is off |
| News | MT5 calendar: 07:00 digest, 60/15/5-min warnings, **actual number instantly**, breakout plan + breakout alert | Weekly calendar in the app + backup warning before high-impact news |
| Lots | From your **live MT5 balance** and HFM contract specs | From `config.json` balance |
| Alerts | MT5 phone push + ntfy + PC pop-up | ntfy / Telegram |

The MT5 engine posts a heartbeat every 5 min. While it's online, the cloud engine **mutes its alerts**, so you never get doubles. The app shows which engine is active.

👉 **Set up the live engine first: [`mt5/AURA_MT5_Setup.md`](mt5/AURA_MT5_Setup.md)**

```
 HFM MT5 (your PC) ── AURA_RealTime EA ──► 🔔 MT5 app push + ntfy  (real time)
        │ heartbeat
        ▼
 GitHub Actions (every 15 min) ── aura_engine.py ──► 🔔 ntfy (only if the PC is off)
        │ commits JSON
        ▼
 GitHub Pages ── AURA app on your phone (trades, news, lot sizes, track record)
```

| Piece | Service | Cost |
|---|---|---|
| Real-time engine + news | HFM MT5 on your PC | **R0** |
| Cloud backup engine | GitHub Actions, public repo | **R0** |
| App / dashboard | GitHub Pages | **R0** |
| Phone push | MT5 app, ntfy app and/or Telegram | **R0** |
| Charts | TradingView Basic (free) | **R0** |

> **Why not TradingView alerts?** On the free plan, indicators can't trigger alerts at all, webhooks need a paid plan, and TradingView adds its own delay. AURA runs the rules itself, on HFM's prices.

### Cloud backup setup (already done for waizyk/aura)
The steps below are only needed if you ever set the cloud backup up again in a new repo.

---

## Setup (about 20 minutes, once)

### 1 · Create the repo
1. Sign in at github.com → **+** (top right) → **New repository**.
2. Name: `aura` · Visibility: **Public** (required for free Pages + unlimited Actions minutes) → **Create repository**.
3. Click **uploading an existing file** and drag in everything from this folder: `config.json`, `README.md`, `engine/`, `docs/`.
4. The `.github` folder is often hidden by your computer, so create it by hand: **Add file → Create new file**, name it exactly
   `.github/workflows/aura-signals.yml`, paste the contents of that file from this package → **Commit changes**.

### 2 · Get your free keys
- **Twelve Data** (recommended, real spot gold prices that match HFM): sign up at twelvedata.com → Dashboard → copy your **API key**.
  *No key? It still works using Yahoo gold futures shifted to spot, but levels can differ from HFM by a dollar or two.*
- **ntfy** (easiest phone push): install the **ntfy** app (Play Store / App Store) → **+** → subscribe to a topic name only you know, e.g. `aura-thabo-7k2q9x`. Anyone who knows the name can read it, so make it random.
- **Telegram** (optional, instead of or as well as ntfy): message **@BotFather** → `/newbot` → copy the token. Send your bot a message, then open `https://api.telegram.org/bot<TOKEN>/getUpdates` and copy the `"chat":{"id": …}` number.

### 3 · Add them as secrets (they stay private, even in a public repo)
Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Name | Value |
|---|---|
| `TWELVEDATA_API_KEY` | your Twelve Data key |
| `NTFY_TOPIC` | your ntfy topic name |
| `TELEGRAM_BOT_TOKEN` | *(optional)* |
| `TELEGRAM_CHAT_ID` | *(optional)* |

### 4 · Allow the bot to save results
Repo → **Settings → Actions → General → Workflow permissions** → **Read and write permissions** → Save.

### 5 · Switch on the app (GitHub Pages)
Repo → **Settings → Pages** → Source: **Deploy from a branch** → Branch **main**, folder **/docs** → Save.
After a minute your app is live at **`https://<your-username>.github.io/aura/`**.

### 6 · First run + phone test
Repo → **Actions** tab → (click *"I understand… enable"* if asked) → **AURA signals** → **Run workflow** → keep "Send a test notification" ticked → **Run**.
Within a minute your phone should get **"✅ AURA test"** and **"✅ AURA engine connected"**. After that it runs by itself every 15 minutes, Sunday to Friday.

### 7 · Install the app on your phone
Open your Pages link → **Chrome:** ⋮ → *Add to Home screen* · **iPhone Safari:** Share → *Add to Home Screen*.

---

## Changing settings
Edit **`config.json`** on GitHub (pencil icon) → Commit. The next run uses the new values.

| Setting | Meaning | Default |
|---|---|---|
| `account` | `cent` (HFM USC), `zar` or `usd` | `cent` |
| `balance` | Balance **exactly as MT5 shows it** (USC for cent). **Update weekly.** | `6000` |
| `timeframes` | any of `"5min"`, `"15min"`, `"1h"`, `"1day"` | `["5min","15min","1day"]` |
| `rr` | Final take profit in R | `3.0` |
| `exit_mode` | `hold` (tested best) or `smart` (auto-exit on rejection / slow-EMA break) | `hold` |
| `be_after_tp1` | Move SL to breakeven after TP1 (tested worse) | `false` |
| `kelly_fraction` / `max_risk_pct` / `start_risk_pct` | Quarter-Kelly, cap, and risk before 30 trades | `0.25` / `2.0` / `1.0` |
| `session` | `all`, `ny` (NY open only) or `london_ny` | `all` |
| `notify_warnings` / `notify_milestones` | Push rejection/exit warnings and TP1/TP2 | `true` |

---

## What you'll receive
```
🟢 AURA · BUY · XAUUSD M15
Entry: 4171.30
SL: 4161.30  ($10.0 away)
TP1: 4181.30  TP2: 4191.30
Final TP (3R): 4201.30
Lot: 0.10 cent lots
Risk: R17.50 = 105 USC (1.75%)
Now: 4172.10 (+0.08R) · ✅ still enterable
NEW TRADE: place SL and TP now, then HOLD
Candle closed 15:45 SA (4 min ago)
```
Then **✅ TP1 / ✅ TP2 / 🎯 TP / 🛑 SL / ⚠️ WARNING / 🔄 REVERSE** as the trade plays out.

---

## Honest limitations
- **GitHub's timer isn't exact.** Scheduled runs are often 3–15 minutes late and can occasionally be skipped at busy times. That's why the **MT5 live engine** is the main engine. The cloud is a backup, acceptable for M15/D1 because every alert says how long ago the candle closed and whether it's **still enterable**. Never chase a trade marked ❌.
- **Public repo:** anyone with the link can see your signals and `config.json` balance. Your keys/tokens (secrets) are **never** visible.
- **60-day rule:** GitHub pauses scheduled workflows in repos with no activity for 60 days. The bot's hourly commits normally keep it active. If you ever get an email saying the workflow was disabled, just click **Enable**.
- **Limits used:** about 2 Twelve Data requests per run (~200/day of the free 800), and well under GitHub's free limits for public repos.
- Prices from Twelve Data / Yahoo can differ from HFM by a few cents to a dollar. Place your SL/TP from the alert and adjust slightly to your broker's quote if needed.
- The engine's stats are a rolling backtest (M5/M15 ~60 days, D1 ~10 years) on the same rules, with a $0.35 spread subtracted. They're not a promise of future results.

## TradingView (charts only)
Alerts come from **this app**, not TradingView. `AURA_Gold_Signals.pine` is a chart-only indicator that uses the same rules, so you can see the setups on your chart:
Pine Editor → paste → Save → **Add to chart** → OANDA:XAUUSD, M5, M15 or D1 (M5 switches to its own settings automatically). It works on the free TradingView plan.

## Files
```
config.json                          ← your settings
engine/aura_engine.py             ← signal engine (pure Python, no installs)
.github/workflows/aura-signals.yml   ← the free 15-minute timer
docs/                                ← the AURA app (GitHub Pages)
mt5/AURA_RealTime.mq5                ← ⚡ real-time MT5 engine + news (compiled: 0 errors, 0 warnings)
mt5/AURA_MT5_Setup.md                ← how to install it
docs/data/state.json, signals.json   ← written by the engine
AURA_Gold_Signals.pine            ← TradingView chart indicator (no alerts)
AURA_Playbook.md                     ← the AURA trading playbook
```

---
*AURA by ACE TECH · a product of ACE OPS · built by Ace Khan*
