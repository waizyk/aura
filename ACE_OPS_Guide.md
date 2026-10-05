# ACE OPS · Gold Trading Playbook

*Indicator: `pine/ACE_OPS_Gold_Signals.pine` · App: `app/` · Research: `research/`*

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

The **Growth** tab in the ACE OPS app lets you play with these numbers.

---

## 2. What I changed from your original indicator, and why

I didn't guess. I rebuilt the indicator's logic in Python and tested **8,640 setting combinations** on real gold prices (COMEX gold futures, which track XAUUSD closely):
- **2.4 years of 1-hour candles.** I picked settings on the first 65%, then checked them on the last 35% the settings had never "seen".
- **~2.5 months of 15-minute candles** as a second check.

**Results (after a $0.35 spread cost per trade):**

| | Your original | **ACE OPS** |
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

## 3. How the ACE OPS signal works

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
| Smallest trade with a typical H1 stop ($16) | **~R2.66 = 0.27% of R1,000** ✓ | ~R266 = **27%** ✗ | ~R266 = **27%** ✗ |
| Smallest trade with a typical M15 stop ($10) | **~R1.66 = 0.17%** ✓ | ~R166 = **17%** ✗ | ~R166 = **17%** ✗ |
| Use it… | **NOW, for all ACE OPS gold trades** | Later, from ~R15,000–R20,000 | Optional, not needed |

**What to do:**
1. Move your trading money (the R1,000) into the **USC cent account**: HFM **myWallet → Internal transfer**. R1,000 ≈ $60 ≈ **6,000 USC**. HFM may charge a small currency conversion fee, so move it once rather than back and forth.
2. In the indicator, under **4 · Account & Kelly lot size**: set **HFM account = Cent (USC)** and **Balance = what MT5 shows** (e.g. 6000).
3. **Do a 30-second check before your first real trade:** open 0.01 lot of gold on the cent account, watch for a few seconds, then close it. A $1 move in gold should change your profit by about **1 USC** (one US cent). If it moves 100 USC per $1 instead, tell me and I'll adjust the contract size setting.
4. Your gold symbol on the cent account may have a suffix (e.g. `XAUUSD.c` or similar). Use whatever your cent account's Market Watch shows. On TradingView keep the chart on **OANDA:XAUUSD**.

**When to move up to the ZAR account:** 0.01 lot on the ZAR account risks about R266 with an H1 stop (about R166 with an M15 stop). To keep that at 2% or less you need at least **~R13,300** (H1) or **~R8,300** (M15). To have room to size properly (0.02+ lots), switch around **R15,000–R20,000**. The ZAR account is the nicest long-term because profits and withdrawals are in rand with no conversion. The USD account isn't needed for this plan.

**Lot size examples on the cent account (R1,000 ≈ 6,000 USC):**

| Risk | H1 stop ~$16 | M15 stop ~$10 |
|---|---|---|
| 1% (first 30 trades) = R10 ≈ 60 USC | **0.03** cent lots | **0.06** cent lots |
| 1.75% (¼ Kelly) = R17.50 ≈ 105 USC | **0.06** cent lots | **0.10** cent lots |

The indicator and the app's **Lot size** tab work this out for every trade. These are just examples.

---

## 7. Which charts to follow

| Priority | Chart | Why |
|---|---|---|
| ⭐ **1** | **XAUUSD 15-minute** | Main chart. ~35 signals/month, highest expectancy in testing. Use during the NY open. |
| ⭐ **2** | **XAUUSD 1-hour** | "Set-and-forget" chart. ~7 signals/month, 2.4 years of proof. Best for evenings/nights: place SL/TP and sleep. |
| 3 | XAUUSD 4-hour (check only) | Look once a day: is the 4H trend up or down? You can switch on "Extra filter: HTF EMA 50" to force alignment. |
| ✗ | 1-min / 5-min | Spread eats the edge. Don't. |
| ✗ | Other markets (EURUSD, NAS100, V75…) | **Not tested.** Before trading another market, run the indicator on it and check the dashboard. You need at least 30 trades with positive expectancy. |

On TradingView use **OANDA:XAUUSD** or your broker's feed if listed. Prices differ by a few cents, so always place SL/TP from the alert values and adjust slightly for your broker's quote if needed.

**One market, mastered, beats five markets done badly.** Stick to gold for your first 3–6 months.

---

## 8. When to trade (South African time)

Gold moves when London and New York are awake. These are **SA times while the US is on summer time (until 1 Nov 2026)**. From 1 Nov to mid-March, the NY times move **one hour later**. The app and indicator adjust automatically.

| SA time | Session | Tested result | Verdict |
|---|---|---|---|
| **14:00 – 18:00** | **New York open** | +0.34R to +0.48R per trade | ⭐ **BEST: trade here** |
| 09:00 – 12:00 | London | slightly positive on H1, negative on M15 | OK on H1, be picky on M15 |
| 12:00 – 14:00 | Lunch | mixed / negative on M15 | Avoid |
| 18:00 – 20:00 | NY afternoon | negative (H1) / flat (M15) | ❌ Avoid |
| **20:00 – 23:00** | Late NY (**your "night"**) | flat to negative | ❌ Weak: plan, don't trade |
| 23:00 – 00:00 | Daily close / break | | Closed |
| 00:00 – 08:00 | Asia | positive on both (but small samples) | OK for H1 set-and-forget |

### "I'd rather trade at night." My honest advice:
Night (20:00–23:00) is gold's weakest window. The volume has left and price chops around. Three better options:
1. **Best:** use the **M15 chart during 14:00–18:00**. If you work, even 15:30–17:30 catches the core of the NY open.
2. **Night-friendly:** use the **H1 chart**. When an alert comes in the evening, place SL + TP and go to bed. The system is built to *hold*, so you don't need to watch it.
3. **Use the night to study:** review your trades, mark key levels and check tomorrow's news calendar.

### High-impact news (SA time, US summer)
- **NFP (jobs):** 1st Friday of the month, **14:30**
- **CPI (inflation):** mid-month, **14:30**
- **FOMC (interest rates):** ~8 times a year, **20:00**, plus press conference at 20:30

Don't open new trades 30 min before or after these. Gold can move $30+ in seconds.

---

## 9. Setup, step by step

### A. TradingView indicator
1. TradingView → **Pine Editor** → paste `ACE_OPS_Gold_Signals.pine` → **Save** → **Add to chart**.
2. Open **XAUUSD, 15-minute**.
3. Settings → **4 · Account**: HFM account = **Cent (USC)**, balance = what MT5 shows in USC (e.g. 6000).
4. Settings → **7 · ACE OPS app**: set a secret word (e.g. `aceops-7Hq2`).

### B. Phone alerts: free option (start here)
1. Alert ⏰ → Condition: **ACE OPS → ACE OPS · BUY** (repeat for SELL, Final TP, Stop loss, Exit warning).
2. Tick **Notify in app**. Install the TradingView app and log in. Done: your phone buzzes on every signal.

### C. Your own ACE OPS app (company-branded)
1. Deploy the `app/` folder (see `app/README.md`). You get a URL like `https://aceops.up.railway.app`.
2. TradingView alert → Condition: **ACE OPS → Any alert() function call** → tick **Webhook URL** → paste `https://<your-url>/webhook`.
   *(Webhooks need a paid TradingView plan, Essential or higher, and 2-factor login switched on.)*
3. On your phone, open your URL in Chrome/Safari → menu → **Add to Home screen**. It installs with the ACE OPS icon.
4. Optional but recommended: connect a **Telegram bot** so alerts arrive even when the app is closed (instructions in `app/README.md`).

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
- The M15 sample is only ~2.5 months (78 trades). Treat its stats as promising, not proven. The H1 results (200 trades, 2.4 years, held-out test) are the more trustworthy ones.
- Live results are usually worse than backtests because of slippage, spread widening at news and human error. That's why the "Realistic" growth preset halves the expectancy.
- HFM's South African entity is FSCA-regulated, but always confirm the entity your account is under on the FSCA website. Never give anyone your MT5 password or let "account managers" trade for you.
- Cent account spreads on gold can be a bit wider than on HFM's other accounts. The backtest assumed $0.35. If your spread is regularly above about $0.50, M15 results will suffer more than H1.

*ACE OPS. Trade the plan, protect the account, compound the years.*
