# ACE OPS · Serverless Gold Signals (100% free)

Everything runs on **your GitHub account**: no server, no monthly bill, no paid TradingView plan.

```
 every 15 min                                     your phone
┌─────────────────┐   new signal?   ┌───────────┐   🔔 push (locked screen too)
│ GitHub Actions  │ ──────────────► │ ntfy /    │ ─────────────────────────────►
│ (free cron)     │                 │ Telegram  │
│ runs ACE OPS    │                 └───────────┘
│ engine (Python) │   commits JSON   ┌───────────────────────────┐
│                 │ ───────────────► │ GitHub Pages (free)       │  ◄── ACE OPS app on
└────────┬────────┘                  │ yourname.github.io/ace-ops│      your home screen
         │ free gold prices          └───────────────────────────┘
   Twelve Data (spot) / Yahoo
```

| Piece | Service | Cost |
|---|---|---|
| Signal engine (same rules as the TradingView indicator) | GitHub Actions, public repo | **R0** |
| App / dashboard (installable on phone) | GitHub Pages | **R0** |
| Gold prices | Twelve Data free key (spot XAU/USD), Yahoo as backup | **R0** |
| Phone push notifications | ntfy app and/or Telegram bot | **R0** |
| Charts with the indicator | TradingView Basic (free; it just can't send alerts) | **R0** |

> **Why not TradingView alerts?** On the free TradingView plan, indicators can't trigger alerts at all (only 3 simple price alerts are allowed), and webhooks need the paid Essential plan + 2FA. So this repo runs the ACE OPS rules itself, and you keep TradingView only for looking at charts.

---

## Setup (about 20 minutes, once)

### 1 · Create the repo
1. Sign in at github.com → **+** (top right) → **New repository**.
2. Name: `ace-ops` · Visibility: **Public** (required for free Pages + unlimited Actions minutes) → **Create repository**.
3. Click **uploading an existing file** and drag in everything from this folder: `config.json`, `README.md`, `engine/`, `docs/`.
4. The `.github` folder is often hidden by your computer, so create it by hand: **Add file → Create new file**, name it exactly
   `.github/workflows/ace-ops-signals.yml`, paste the contents of that file from this package → **Commit changes**.

### 2 · Get your free keys
- **Twelve Data** (recommended, real spot gold prices that match HFM): sign up at twelvedata.com → Dashboard → copy your **API key**.
  *No key? It still works using Yahoo gold futures shifted to spot, but levels can differ from HFM by a dollar or two.*
- **ntfy** (easiest phone push): install the **ntfy** app (Play Store / App Store) → **+** → subscribe to a topic name only you know, e.g. `aceops-thabo-7k2q9x`. Anyone who knows the name can read it, so make it random.
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
After a minute your app is live at **`https://<your-username>.github.io/ace-ops/`**.

### 6 · First run + phone test
Repo → **Actions** tab → (click *"I understand… enable"* if asked) → **ACE OPS signals** → **Run workflow** → keep "Send a test notification" ticked → **Run**.
Within a minute your phone should get **"✅ ACE OPS test"** and **"✅ ACE OPS engine connected"**. After that it runs by itself every 15 minutes, Sunday to Friday.

### 7 · Install the app on your phone
Open your Pages link → **Chrome:** ⋮ → *Add to Home screen* · **iPhone Safari:** Share → *Add to Home Screen*.

---

## Changing settings
Edit **`config.json`** on GitHub (pencil icon) → Commit. The next run uses the new values.

| Setting | Meaning | Default |
|---|---|---|
| `account` | `cent` (HFM USC), `zar` or `usd` | `cent` |
| `balance` | Balance **exactly as MT5 shows it** (USC for cent). **Update weekly.** | `6000` |
| `timeframes` | `["15min","1h"]`, `["15min"]` or `["1h"]` | both |
| `rr` | Final take profit in R | `3.0` |
| `exit_mode` | `hold` (tested best) or `smart` (auto-exit on rejection / slow-EMA break) | `hold` |
| `be_after_tp1` | Move SL to breakeven after TP1 (tested worse) | `false` |
| `kelly_fraction` / `max_risk_pct` / `start_risk_pct` | Quarter-Kelly, cap, and risk before 30 trades | `0.25` / `2.0` / `1.0` |
| `session` | `all`, `ny` (NY open only) or `london_ny` | `all` |
| `notify_warnings` / `notify_milestones` | Push rejection/exit warnings and TP1/TP2 | `true` |

---

## What you'll receive
```
🟢 ACE OPS · BUY · XAUUSD M15
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
- **GitHub's timer isn't exact.** Scheduled runs are often 3–15 minutes late and can occasionally be skipped at busy times. That's fine for H1, and acceptable for M15 because every alert says how long ago the candle closed and whether it's **still enterable**. Never chase a trade marked ❌.
- **Public repo:** anyone with the link can see your signals and `config.json` balance. Your keys/tokens (secrets) are **never** visible.
- **60-day rule:** GitHub pauses scheduled workflows in repos with no activity for 60 days. The bot's hourly commits normally keep it active. If you ever get an email saying the workflow was disabled, just click **Enable**.
- **Limits used:** about 2 Twelve Data requests per run (~200/day of the free 800), and well under GitHub's free limits for public repos.
- Prices from Twelve Data / Yahoo can differ from HFM by a few cents to a dollar. Place your SL/TP from the alert and adjust slightly to your broker's quote if needed.
- The engine's stats are a rolling backtest of the last ~2 months (M15) and ~10 months (H1) on the same rules. They're not a promise of future results.

## TradingView (charts only)
Alerts come from **this app**, not TradingView. `ACE_OPS_Gold_Signals.pine` is a chart-only indicator that uses the same rules, so you can see the setups on your chart:
Pine Editor → paste → Save → **Add to chart** → OANDA:XAUUSD, M15 or H1. It works on the free TradingView plan.

## Files
```
config.json                          ← your settings
engine/ace_ops_engine.py             ← signal engine (pure Python, no installs)
.github/workflows/ace-ops-signals.yml← the free 15-minute timer
docs/                                ← the ACE OPS app (GitHub Pages)
docs/data/state.json, signals.json   ← written by the engine
ACE_OPS_Gold_Signals.pine            ← TradingView chart indicator (no alerts)
ACE_OPS_Guide.md                     ← the ACE OPS trading playbook
```
