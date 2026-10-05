# AURA Real-Time Engine · MT5 setup (Windows PC)

**AURA by ACE TECH** · a product of **ACE OPS** · built by **Ace Khan**

The AURA EA runs inside your **HFM MetaTrader 5** on your PC. It uses HFM's own live prices, so there's **no TradingView delay**. It:

- sends **M5 · M15 · D1** signals on the first tick after a candle closes;
- sends TP1 / TP2 / TP / SL alerts on the tick that touches the level;
- reads the **MT5 economic calendar** and warns you 60 / 15 / 5 min before high-impact news, with the forecast, previous and likely gold reaction plus a breakout plan;
- alerts the **actual number** the moment MT5 receives it, then the **price breakout**;
- works out the **lot size from your live balance** and HFM's contract specs, using quarter-Kelly with a 2% cap;
- pushes to your **phone** (MT5 app + ntfy/AURA app), with a pop-up and sound on the PC.

> **Alerts only.** The EA never opens, changes or closes a trade. You stay in control.

Time needed: about 15 minutes, once.

---

## 1 · Install HFM MT5 and log in
1. Download **MT5 for Windows** from your HFM client area (myHF → Downloads), install it, and log in with your **cent (USC) account** number, password and server.
2. Open **Market Watch** (Ctrl+M) and make sure **XAUUSD** is listed. It may have a suffix on cent accounts, e.g. `XAUUSD.c`. Right-click → *Show All* if you can't see it.
3. Optional but useful: also show **USDZAR**. AURA then converts every risk amount to rand.

## 2 · Install the AURA EA
1. In MT5: **File → Open Data Folder**.
2. Open `MQL5` → `Experts`. Copy **`AURA_RealTime.mq5`** into that folder.
3. Back in MT5, press **F4** to open MetaEditor. In the Navigator on the left, find *Experts → AURA_RealTime.mq5*, double-click it, then press **F7** (Compile).
   You should see **"0 errors, 0 warnings"**. It was compiled with MetaTrader 5's own compiler before you got it.
4. Close MetaEditor. In MT5's **Navigator** (Ctrl+N) → *Expert Advisors* → right-click → *Refresh*. **AURA_RealTime** appears.

## 3 · Allow phone alerts
**A. MT5 phone app push (short alerts)**
1. On your phone: open the **MetaTrader 5** app → *Settings* (or *Messages*) → copy your **MetaQuotes ID** (8 characters).
2. On the PC: **Tools → Options → Notifications** → tick *Enable Push Notifications* → paste the MetaQuotes ID → click **Test**. Your phone should buzz.

**B. ntfy / AURA app (full alerts with the AURA icon)**
1. **Tools → Options → Expert Advisors** → tick **Allow WebRequest for listed URL** → add `https://ntfy.sh` → OK.
2. You'll paste your ntfy topic into the EA in the next step.

## 4 · Start AURA
1. Open an **XAUUSD** chart. Any timeframe works; **M15** is a good default.
2. Drag **AURA_RealTime** from the Navigator onto the chart.
3. On the **Common** tab, tick *Allow Algo Trading*. It only *sends alerts*; MT5 just needs this switch on for any EA to run.
4. On the **Inputs** tab:
   - **ntfy topic** → paste your AURA topic (e.g. `aura-8ck0escb6rgh`).
   - Leave the rest on the defaults to start.
5. Click **OK**. Then make sure the **Algo Trading** button in the toolbar is **green**.
6. Within seconds you get **"⚡ AURA live engine ONLINE"** on your phone. The info panel appears at the top-left of the chart.

**Keep it running:** Windows Settings → System → Power → set *Sleep* to **Never** while plugged in. If the PC sleeps, the engine sleeps. When the PC is off, the cloud backup (GitHub) takes over, with alerts every ~15 min. The AURA app shows which one is active.

## 5 · What you'll see on the chart
```
AURA · Gold Signals   by ACE TECH · a product of ACE OPS · built by Ace Khan
XAUUSD   Bid 4155.30   Spread $0.25   Balance 6000.00 USC
SA 14:35   New York open: BEST
M5  : FLAT · trend DOWN
      114 trades · win 36.0% · exp +0.17R · max DD 16.4R · risk 1.75%
M15 : SELL 4133.00  SL 4141.20  TP 4108.40  +0.6R · HOLD: trend intact
D1  : FLAT · trend UP
News: clear
  Thu 14:30 SA (2d)  USD Core CPI m/m  F 0.3%  P 0.4%
Last alerts: …
```
- The track record for each timeframe is rebuilt from **HFM's own history**, with a $0.35 spread subtracted, every time the EA starts.
- **Entry / SL / TP lines** are drawn for the chart's timeframe. News breakout levels appear as blue and red dash-dot lines.

## 6 · Inputs worth knowing
| Input | Default | Meaning |
|---|---|---|
| M5 / M15 / D1 signals | on / on / on | Switch timeframes on or off |
| Max risk per trade | 2% | Hard cap, even if Kelly says more |
| Risk until enough trades | 1% | Used until 30 trades of history exist |
| M5 settings | 13/34, trend 2400, 2.5R | Backtested M5 rules (the 9/21 rules lose money on M5) |
| Pause before / after news | 30 / 15 min | Normal signals are skipped in this window |
| News trade risk | 1% | Smaller because of slippage |
| News trade target | 2R | |
| Breakout window | 20 min | No breakout in 20 min = no news trade |
| Spread warning | $0.80 | Alerts warn you when the spread is wider |
| Daily digest hour | 07:00 SA | Morning list of today's news (−1 = off) |
| Include medium-impact news | off | Turn on for more (smaller) events |
| Currencies to watch | USD | Gold reacts mainly to USD news |

## 7 · Troubleshooting
| Problem | Fix |
|---|---|
| No ntfy alerts, but MT5 push works | Tools → Options → Expert Advisors → add `https://ntfy.sh` to the WebRequest list. Check the *Experts* tab for "ntfy blocked". |
| No MT5 push | Re-enter your MetaQuotes ID and press Test. MT5 allows about 10 pushes a minute; AURA queues the rest. |
| Panel says "loading history" | MT5 is downloading candles. Scroll the M5 chart back a bit, or wait a minute. |
| Smiley face is grey / "Algo trading disabled" | Click the **Algo Trading** button so it's green. |
| News list empty | Your MT5 must be connected to HFM. The calendar comes through the broker connection. Check *View → Calendar* (or the *Calendar* tab) shows events. |
| Lot says "below the minimum: SKIP" | The stop is too wide for your balance at the chosen risk. That's AURA protecting you. Skip it. |

## 8 · Honest limits
- **Nobody** gets the news number before it's published. AURA gets it the moment MT5 does (usually within a second or two) and alerts the price breakout, which is often faster still.
- Phone push delivery normally takes 1–3 seconds, but depends on your phone and network.
- At news, spreads widen and orders slip. That's why news trades use 1% risk and come with a spread warning.
- Backtests: M15 about +0.27R per trade, M5 about +0.17R (60 days only, experimental), D1 rare and flat since 2020. Past results don't guarantee future results.

*AURA by ACE TECH · a product of ACE OPS · built by Ace Khan*
