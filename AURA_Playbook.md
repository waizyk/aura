# AURA · Gold Trading Playbook

**AURA by ACE TECH** · a product of **ACE OPS** · built by **Ace Khan**

*Indicator: `AURA_Gold_Signals.pine` · App: https://waizyk.github.io/aura/ · Engine: `engine/aura_engine.py`*

> Read this once fully, then keep the **Trade Routine** (section 5) open next to MT5 until you know it by heart.
> Nothing here is financial advice. Trading leveraged CFDs can lose you all your money, quickly.

---

## 1. First, the honest maths: R1,000 → R1,000,000

R1,000,000 is **1,000×** your money, which means doubling your account about 10 times in a row.

| Monthly growth | Time with **no** deposits | Time with **R500/month** deposits |
|---|---|---|
| 3% (a solid, realistic result) | ~19 years | ~11 years |
| 5% (very good) | ~12 years | ~8 years |
| 8% (elite) | ~7.5 years | ~5.5 years |

People who try to "skip" this by using big lots almost always blow the account, usually within weeks. With R1,000, one bad gold candle at full size can end it.

**What actually gets you there:**
1. **Survive.** Risk 1–2% per trade so that a 7-loss streak (it *will* happen; the backtest had one) costs about 10%, not 100%.
2. **Add money.** In year 1, your monthly deposits will grow the account more than trading will. That's normal.
3. **Compound for years.** Increase lot sizes as your balance grows; the Kelly calculator does this for you.
4. **Grow your track record.** After 6–12 months of proven results you can apply for prop-firm funded accounts (e.g. a $10k–$100k account for a fee). That's the fastest *legitimate* way to trade bigger money.

The **Growth** tab in the AURA app lets you play with these numbers.

---

## 2. What I changed from your original indicator, and why

I didn't guess. I rebuilt the indicator's logic in Python and tested **8,640 setting combinations** on real gold prices (COMEX gold futures, which track XAUUSD closely):
- **2.4 years of 1-hour candles.** I picked settings on the first 65%, then checked them on the last 35% the settings had never "seen".
- **~2.5 months of 15-minute candles** as a second check.

**Results (after a $0.35 spread cost per trade):**

| | Your original | **AURA** |
|---|---|---|
| Settings | EMA 5/13, SL = candle ± 0.5 ATR, 3R | **EMA 9/21 + EMA 200 trend filter**, SL = candle ± **0.3** ATR, 3R |
| Trades per month (H1) | 28 | **7** (fewer, better) |
| Win rate (H1) | 30.8% | **31.5%** |
| Avg profit per trade (H1) | +0.085R | **+0.20R** (2.4× better) |
| Avg profit per trade (M15) | +0.063R | **+0.28R** |
| Worst drawdown (H1) | 19.7R | **8.8R** (half) |
| Longest losing streak (H1) | 17 | **7** |
| Full Kelly (H1) | 4.2% | **7.2%** |

**R** = the amount you risk. If you risk R20 on a trade, +3R = +R60 and −1R = −R20.

**Things that sounded smart but made results WORSE on gold (so they're OFF by default):**
- Moving SL to breakeven after TP1: profit per trade fell from 0.23R to 0.08R on H1.
- Exiting when price closes back past the slow EMA: 0.23R fell to 0.10R.
- ADX "trend strength" filter: worse in every test.
- Partial take-profits at 1R/2R: cut the big winners that pay for all the losses.

**The big lesson:** this system wins only about 1 in 3 trades. It makes money because winners are 3× bigger than losers. Cut the winners short and the edge disappears.

**Bugs fixed from the original:** intermediate TP loop running backwards when R:R < 2, lines jumping to the current bar instead of the entry, signals possibly repainting mid-candle (now everything is decided on candle close), and no lot sizing at all.

---

## 3. How the AURA signal works

**BUY** when ALL are true on a *closed* candle:
1. Fast EMA (9) crosses **above** slow EMA (21)
2. That candle closes **green** (confirmation)
3. Price is **above EMA 200** (only buy in an uptrend)

**SELL** is the mirror: cross below, red candle, below EMA 200.

**Stop loss:** just beyond the signal candle's low (buy) or high (sell), plus 0.3 × ATR as a buffer against stop hunts.
**TP1 = 1R, TP2 = 2R** are milestones (alerts only). **Final TP = 3R** is where you actually close.
**Opposite signal** while in a trade: the old trade is invalidated. Close it and take the new one.

### On the chart
| Mark | Meaning |
|---|---|
| 🟢 **BUY 0.05** / 🔴 **SELL 0.05** | Entry signal + your lot size (hover for full details) |
| Red/green boxes | Your risk zone and reward zone |
| **TP1 / TP2** ▼ | Milestones hit, keep holding |
| 🎯 **TP** | Final target hit |
| **SL** ✕ | Stopped out (normal, it happens ~2 in 3 trades) |
| ⚠ | Rejection candle against you (watch the next close) |
| **EXIT?** | Rejection confirmed or trend broken (see section 4) |
| **INV** | Trade invalidated by an opposite signal |
| Teal background | New York open, the best trading window |

### The dashboard (top right)
Position · **Advice** (HOLD / CAUTION / WAIT) · Entry · SL · TP1/TP2 · Final TP · live P/L in R · **Still enterable?** · **Lot size** · Risk in Rand · Session quality · win rate · avg win:loss · expectancy · Kelly · max drawdown.

The stats in the bottom half come from the indicator's own past signals on **that chart and timeframe**. If Kelly turns red ("no edge"), don't trade that chart.

---

## 4. Hold or pull out?

**Default rule (tested best): HOLD until SL or final TP.** Your SL already caps the loss. Leave the trade alone.

The indicator still tells you what's happening:

| Advice | What it means | What you do |
|---|---|---|
| **HOLD: trend intact** | Price on the right side of the EMAs | Nothing. Walk away. |
| **HOLD: pullback inside trend** | Price dipped past the fast EMA | Nothing. Normal breathing. |
| **CAUTION: rejection candle** | Long wick against you (≥60% of the candle, ≥0.8 ATR) | Watch the *next* candle close |
| **HOLD (warning…)** + **EXIT?** | Next candle confirmed the rejection, or price closed past the slow EMA | Your choice: see below |

**When to act on EXIT? anyway:**
- A **high-impact news** release is about to hit (NFP, CPI, FOMC) and you're in profit
- It's **Friday evening** and you don't want to hold over the weekend gap
- You're up more than +1.5R and the EXIT? appears right at a big round number (e.g. 4200.00)

If you'd rather have the indicator close trades for you, set **Exit mode → Smart exit**. It's safer-feeling, but expect lower profits over time.

**Never:** move your SL further away, add to a losing trade, or close a winner at +0.5R because you're nervous.

---

## 5. The trade routine (print this)

When a **BUY/SELL** alert arrives:
1. ☐ **Session check.** Is it the NY open (best) or London (OK)? If it's "WEAK: late NY", only take it if you can place SL/TP and walk away.
2. ☐ **News check.** Any red-folder USD news in the next 30 min (ForexFactory calendar)? If yes, skip.
3. ☐ **"Still enterable?" = YES.** If price already ran more than 0.25R past entry, **don't chase**; wait for the next signal.
4. ☐ **Lot size.** Use the lot shown. If it says "< 0.01 (too small)", **skip** the trade.
5. ☐ **Place the order in HFM MT5** on your **cent (USC) account's gold symbol**, and type in the SL and the **Final TP** immediately.
6. ☐ **Hold.** Close the app. Check back only on alerts.

**Daily / weekly circuit breakers:**
- 3 losses in one day → **stop for the day.**
- Down 6R in a week → **stop for the week** and review.
- Never trade to "win it back".

---

## 6. Lot sizes and the Kelly principle

### The formula
**Kelly % = W − (1 − W) ÷ B**
- W = win rate (0.315)
- B = average win ÷ average loss (2.8)
- 0.315 − 0.685 ÷ 2.8 = **7.0%** ← this is "full Kelly"

Full Kelly gives the fastest growth *in theory*, but only if your W and B are exactly right (they never are). In practice it brings 50%+ drawdowns. Professionals use **¼ Kelly**:
**7.0% × ¼ ≈ 1.75% risk per trade**, capped at 2%.

The indicator does this automatically:
- **First 30 trades on a chart:** risk 1% (Kelly isn't reliable yet)
- **After that:** ¼ × live Kelly, capped at 2%
- **Kelly ≤ 0:** "NO EDGE, skip"

### From risk % to lots (gold)
```
Lots = Risk in Rand ÷ (SL distance in $ × ounces per lot × USD/ZAR)
```
- **HFM ZAR / USD account (standard lots):** 1.00 lot = 100 oz → 0.01 lot = $1 per $1 move
- **HFM cent (USC) account:** 1 cent lot = 1/100 of a standard lot → 0.01 lot = $0.01 (1 USC) per $1 move

### Your three HFM accounts: which one to use

| | **USC (cent)** | ZAR account | USD account |
|---|---|---|---|
| Balance shows as | US cents (100 USC = $1) | Rand | Dollars |
| 0.01 lot of gold = per $1 move | **1 US cent (~R0.17)** | $1 (~R16.60), booked in rand | $1 |
| Smallest trade with a typical M5 stop ($5) | **~R0.83 = 0.08% of R1,000** ✓ | ~R83 = **8%** ✗ | ~R83 = **8%** ✗ |
| Smallest trade with a typical M15 stop ($10) | **~R1.66 = 0.17%** ✓ | ~R166 = **17%** ✗ | ~R166 = **17%** ✗ |
| Smallest trade with a typical D1 stop ($60) | **~R10 = 1%** ✓ | ~R1,000 = **100%** ✗✗ | ~R1,000 = **100%** ✗✗ |
| Use it… | **NOW, for all AURA gold trades** | Later, from ~R15,000–R20,000 | Optional, not needed |

**What to do:**
1. Move your trading money (the R1,000) into the **USC cent account**: HFM **myWallet → Internal transfer**. R1,000 ≈ $60 ≈ **6,000 USC**. HFM may charge a small currency conversion fee, so move it once rather than back and forth.
2. In the indicator, under **4 · Account & Kelly lot size**: set **HFM account = Cent (USC)** and **Balance = what MT5 shows** (e.g. 6000).
3. **Do a 30-second check before your first real trade:** open 0.01 lot of gold on the cent account, watch for a few seconds, then close it. A $1 move in gold should change your profit by about **1 USC** (one US cent). If it moves 100 USC per $1 instead, tell me and I'll adjust the contract size setting.
4. Your gold symbol on the cent account may have a suffix (e.g. `XAUUSD.c` or similar). Use whatever your cent account's Market Watch shows. On TradingView keep the chart on **OANDA:XAUUSD**.

**When to move up to the ZAR account:** 0.01 lot on the ZAR account risks about R166 with an M15 stop (about R1,000 with a D1 stop). To keep that at 2% or less you need at least **~R8,300** for M15 and **~R50,000** for D1. To have room to size properly (0.02+ lots), switch around **R15,000–R20,000**. The ZAR account is the nicest long-term because profits and withdrawals are in rand with no conversion. The USD account isn't needed for this plan.

**Lot size examples on the cent account (R1,000 ≈ 6,000 USC):**

| Risk | M5 stop ~$5 | M15 stop ~$10 | D1 stop ~$60 |
|---|---|---|---|
| 1% (first 30 trades) = R10 ≈ 60 USC | **0.12** cent lots | **0.06** cent lots | **0.01** cent lots |
| 1.75% (¼ Kelly) = R17.50 ≈ 105 USC | **0.21** cent lots | **0.10** cent lots | **0.01** cent lots |

Same risk in rand on every timeframe: only the lot changes. The MT5 EA works this out from your live balance and HFM's contract specs for every alert. These are just examples.

---

## 7. Which charts to follow (M5 · M15 · D1)

Backtest on gold, same rules, **after a $0.35 spread** (October 2026):

| Chart | Settings | Trades / month | Win rate | Avg per trade | Worst drawdown | Longest losing run | Verdict |
|---|---|---|---|---|---|---|---|
| **M15** ⭐ | EMA 9/21, trend 200, 3R | ~34 | 32.9% | **+0.27R** | 8.9R | 6 | **Main chart** |
| **M5** | EMA 13/34, trend 2400 (= H1 200 EMA), 2.5R | ~50 | 36.0% | +0.17R | 16.4R | 8 | Experimental: only with the stricter M5 settings |
| M5 (old 9/21 rules) | | ~100 | 26.3% | −0.03R ✗ | 20.4R | 14 | Loses money: that's why M5 has its own settings |
| M1 | | ~580 | 20.9% | −0.34R ✗ | 51R | 12 | ❌ Never: the spread eats everything |
| **D1** | EMA 9/21, trend 200, 3R | ~0.3 (4 a year) | 34.1% (20 yrs) | +0.36R (20 yrs), **~0R since 2020** | 11.9R | 11 | **Big-picture bias**, rare trades |

**How to use them together**
1. **D1 = direction.** Every M5/M15 alert says whether the trade is *with* or *against* the daily trend. With it: normal. Against it: be extra strict or skip.
2. **M15 = your main entries.** Best expectancy, smallest drawdowns.
3. **M5 = extra entries for when you're at the screen during 14:00–18:00 SA.** It's noisier (8 losses in a row happened in testing), and only 60 days of data exist, so treat it as experimental. AURA's Kelly check switches it to "SKIP (no edge)" automatically if it starts losing.

### "Doesn't H1 / a bigger timeframe blow the account faster?"
No. AURA sizes every lot so that **a stop-loss costs the same 1–2% of your balance on every timeframe**. A bigger timeframe just means a wider stop with a *smaller* lot. What blows accounts is **risk per trade** (and over-trading), not the timeframe. Smaller timeframes are actually *riskier* for a small account: the spread is a bigger share of a tight stop, news spikes jump straight through it, and you take far more trades.

On TradingView use **OANDA:XAUUSD**. The indicator switches to the M5 settings by itself on the 5-minute chart. The **MT5 EA uses HFM's own prices**, so its levels match your broker exactly.

**One market, mastered, beats five markets done badly.** Stick to gold for your first 3–6 months.

---

## 8. When to trade (South African time)

Gold moves when London and New York are awake. These are **SA times while the US is on summer time (until 1 Nov 2026)**. From 1 Nov to mid-March, the NY times move **one hour later**. The app and indicator adjust automatically.

| SA time | Session | Tested result | Verdict |
|---|---|---|---|
| **14:00 – 18:00** | **New York open** | +0.34R to +0.48R per trade | ⭐ **BEST: trade here** |
| 09:00 – 12:00 | London | mixed, negative on M15 | Be picky: only with the daily trend |
| 12:00 – 14:00 | Lunch | mixed / negative on M15 | Avoid |
| 18:00 – 20:00 | NY afternoon | flat (M15) | ❌ Avoid |
| **20:00 – 23:00** | Late NY (**your "night"**) | flat to negative | ❌ Weak: plan, don't trade |
| 23:00 – 00:00 | Daily close / break | | Closed |
| 00:00 – 08:00 | Asia | small samples | M15 only, never M5 |

### "I'd rather trade at night." My honest advice:
Night (20:00–23:00) is gold's weakest window. The volume has left and price chops around. Three better options:
1. **Best:** use the **M15 chart during 14:00–18:00**. If you work, even 15:30–17:30 catches the core of the NY open.
2. **Night-friendly:** only take **M15 alerts that agree with the daily trend** (the alert tells you). Place SL + TP and go to bed. The system is built to *hold*. Never scalp M5 at night.
3. **Use the night to study:** review your trades, check the D1 bias and read tomorrow's news in the AURA app or the 07:00 news digest.

### High-impact news (SA time, US summer)
- **NFP (jobs):** 1st Friday of the month, **14:30**
- **CPI (inflation):** mid-month, **14:30**
- **FOMC (interest rates):** ~8 times a year, **20:00**, plus press conference at 20:30

Gold can move $30+ in seconds. See section 8b for exactly how AURA handles news.

---

## 8b. News trading with AURA

**The honest truth first:** nobody can know the number before it's released. Anyone who "knows" it is guessing, or breaking the law. What AURA gives you *before* the release is everything you need to be ready, and what it gives you *at* the release is speed.

| When | What the MT5 EA sends you |
|---|---|
| 07:00 SA | 📅 **Today's news digest**: every high-impact USD event with forecast and previous |
| 60 min before | 📅 Warning, forecast vs previous, **"if actual > forecast → gold likely DOWN"** (and the opposite), and what the market already expects |
| 15 min before | Same + the **pre-news range** and the breakout plan: BUY above X / SELL below Y with SL, TP and lot size |
| 5 min before | Final levels. Spreads are widening, open trades get a "bank profit or move SL to entry" reminder |
| **0 sec** | 🔴 **NEWS LIVE**: range frozen, breakout levels drawn on your chart |
| **The second MT5 receives the number** | 📰 **Result**: actual vs forecast → "GOLD BEARISH / BULLISH" |
| **The tick price breaks out** | 🟢/🔴 **NEWS TRADE**: entry, SL, TP, lot (1% risk), spread warning, and whether the **data agrees** with the move |
| 20 min after, no breakout | ⏹ No trade |

**Rules**
- Normal AURA signals are **paused 30 min before to 15 min after** every high-impact event (they would be hit by the spread blow-out).
- News trades risk **1%** (half the normal maximum), because slippage at news can make a 1R loss into 1.5R.
- If the alert says **"⚠️ Data DISAGREES"**, skip. Those are the classic fake-outs.
- Spread above $0.80? Wait 10–30 seconds for it to come back in, then enter only if price is still beyond the level.
- **Fastest option:** at the 5-min warning, place the two stop orders from the plan (buy stop + sell stop) and delete the other one when one fills.
- The result usually arrives in MT5 within a second or two of the release. Price moves in milliseconds, which is why AURA also alerts the **price breakout** itself, not only the number.

**Real-time vs TradingView:** the EA runs inside your HFM MT5, on HFM's own price feed. Signals fire on the first tick after a candle closes, and SL/TP alerts fire on the tick that touches the level. There's no TradingView in the loop, so no TradingView delay. The phone push itself usually takes 1–3 seconds.

---

## 9. Setup, step by step

### A. The real-time engine (MT5 on your Windows PC). Start here.
Full guide with pictures-in-words: **`mt5/AURA_MT5_Setup.md`**. Short version:
1. Install **HFM MT5** on your PC and log in to your account.
2. MT5 → File → Open Data Folder → `MQL5/Experts` → copy **`AURA_RealTime.mq5`** there → in MetaEditor press **F7** (Compile).
3. Tools → Options → **Expert Advisors**: tick *Allow WebRequest* and add `https://ntfy.sh`.
4. Tools → Options → **Notifications**: enter your **MetaQuotes ID** from the MT5 phone app.
5. Open an **XAUUSD** chart → drag **AURA_RealTime** onto it → Inputs: paste your ntfy topic → OK. Click **Algo Trading** so it's green.
6. You'll get "⚡ AURA live engine ONLINE" on your phone. Keep the PC on (sleep off) while you trade.

### B. Phone alerts
- **ntfy app** → subscribe to your AURA topic (full alerts, AURA icon).
- **MT5 phone app** → push notifications arrive automatically (short version).

### C. The AURA app (dashboard + cloud backup)
Open **https://waizyk.github.io/aura/** → Add to Home screen. It shows whether the MT5 engine is online, the week's news, trades, lot sizes and the track record. When your PC is **off**, the cloud backup sends alerts every ~15 min (can be late). When the PC engine is **on**, cloud alerts are muted, so you never get doubles.

### D. TradingView (charts only)
Pine Editor → paste `AURA_Gold_Signals.pine` → Save → Add to chart → OANDA:XAUUSD on M5, M15 or D1.

### E. Keep it in sync
The EA reads your balance from MT5 automatically. For the cloud backup, update `balance` in `config.json` every week or so.

---

## 10. Your first 90 days

| Weeks | Goal |
|---|---|
| 1–2 | Run the indicator, **paper-trade every signal** in a notebook or an HFM demo account. Learn the routine. |
| 3–4 | Go live on your **HFM USC cent account** at **1% risk**. Follow the routine exactly, even when it's boring. |
| 5–12 | Reach **30+ live trades**. Compare your live win rate and avg win:loss with the backtest. If live expectancy is positive, let Kelly take over (max 2%). |
| Every week | Update the USC balance in the indicator settings, review losses (was it the system or was it you?), and deposit what you can. |

**Journal every trade:** date, time, session, entry, SL, TP, lots, result in R, did you follow the rules (Y/N). The "Y/N" column will teach you more than any indicator.

---

## 11. Limitations (please read)
- The backtest used gold **futures** data. Your broker's XAUUSD will differ slightly.
- 2024–2026 was a strong gold bull market. Trend-following thrives in trends, and a long sideways market will hurt any trend system.
- The M15 sample is only ~2.5 months (79 trades) and M5 only 60 days. Treat their stats as promising, not proven. D1 has 20 years but only ~80 trades, and it's been flat since 2020. The EA recalculates every track record from HFM's own history each time it starts.
- Live results are usually worse than backtests because of slippage, spread widening at news and human error. That's why the "Realistic" growth preset halves the expectancy.
- HFM's South African entity is FSCA-regulated, but always confirm the entity your account is under on the FSCA website. Never give anyone your MT5 password or let "account managers" trade for you.
- Cent account spreads on gold can be a bit wider than on HFM's other accounts. The backtest assumed $0.35. If your spread is regularly above about $0.50, M15 results will suffer more than H1.

*AURA by ACE TECH · a product of ACE OPS · built by Ace Khan.*
*Trade the plan, protect the account, compound the years.*
