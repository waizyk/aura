//+------------------------------------------------------------------+
//|                                              AURA_RealTime.mq5   |
//|      AURA by ACE TECH · a product of ACE OPS · built by Ace Khan |
//|                                                                  |
//|  Real-time gold signals inside MT5 (zero delay, HFM's own prices)|
//|  · AURA signals on M5, M15 and D1, sent the second a candle closes|
//|  · TP / SL / warnings on every tick                              |
//|  · News engine: MT5 economic calendar (forecast, previous and    |
//|    the actual number the moment it is published), pre-news       |
//|    warnings, breakout plan and instant breakout alerts           |
//|  · Lot sizes from your live balance + quarter-Kelly              |
//|  · Alerts: MT5 phone app push, ntfy (AURA app), pop-up, sound    |
//|                                                                  |
//|  ALERTS ONLY: this EA never opens, changes or closes trades.     |
//+------------------------------------------------------------------+
#property copyright   "ACE TECH · a product of ACE OPS · built by Ace Khan"
#property link        "https://waizyk.github.io/aura/"
#property version     "1.00"
#property description "AURA real-time gold signals (M5 · M15 · D1) + news engine."
#property description "Alerts only: it never places, changes or closes trades."
#property description "AURA by ACE TECH · a product of ACE OPS · built by Ace Khan"

//──────────────────────────────── inputs ────────────────────────────
input group "1 · Timeframes"
input bool   InpUseM5           = true;   // M5 signals (scalping, stricter rules)
input bool   InpUseM15          = true;   // M15 signals (main timeframe)
input bool   InpUseD1           = true;   // D1 signals (big picture, rare)

input group "2 · Risk (lots use your live MT5 balance)"
input double InpKellyFraction   = 0.25;   // Kelly fraction (0.25 = quarter Kelly)
input double InpMaxRiskPct      = 2.0;    // Max risk per trade (%)
input double InpStartRiskPct    = 1.0;    // Risk (%) until enough trades for Kelly
input int    InpMinTradesKelly  = 30;     // Trades needed before Kelly is trusted
input double InpStatsSpread     = 0.35;   // Spread cost used in the track record ($)

input group "3 · Strategy: M15 and D1"
input int    InpFast            = 9;      // Fast EMA
input int    InpSlow            = 21;     // Slow EMA
input int    InpTrend           = 200;    // Trend EMA
input double InpRR              = 3.0;    // Final target (R)

input group "3b · Strategy: M5 (stricter, backtested)"
input int    InpM5Fast          = 13;     // M5 fast EMA
input int    InpM5Slow          = 34;     // M5 slow EMA
input int    InpM5Trend         = 2400;   // M5 trend EMA (2400 x M5 = H1 200 EMA)
input double InpM5RR            = 2.5;    // M5 final target (R)

input group "3c · Shared rules"
input int    InpAtrLen          = 14;     // ATR length
input double InpSlAtrBuf        = 0.3;    // SL buffer beyond signal candle (x ATR)
input bool   InpConfirm         = true;   // Require a confirmation candle
input double InpLateEntryR      = 0.25;   // "Still enterable" up to this R
input double InpRejWickPct      = 60;     // Rejection wick (% of candle)
input double InpRejMinAtr       = 0.8;    // Rejection candle min size (x ATR)
input bool   InpWarnings        = true;   // Send HOLD warnings
input bool   InpMilestones      = true;   // Send TP1 / TP2 milestones

input group "4 · News engine (MT5 economic calendar)"
input bool   InpNewsOn          = true;   // News engine on
input string InpNewsCurrencies  = "USD";  // Currencies to watch (comma separated)
input bool   InpNewsMedium      = false;  // Include medium-impact news
input int    InpPauseBefore     = 30;     // Pause normal signals X min before news
input int    InpPauseAfter      = 15;     // ...and X min after
input int    InpRangeMin        = 30;     // Pre-news range length (minutes)
input double InpBreakBufAtr     = 0.25;   // Breakout buffer (x M5 ATR)
input double InpNewsRR          = 2.0;    // News trade target (R)
input double InpNewsRiskPct     = 1.0;    // News trade risk (%)
input int    InpBreakWindow     = 20;     // Watch for breakout X min after release
input double InpMaxSpreadUsd    = 0.80;   // Spread warning above this ($)
input int    InpDigestHourSA    = 7;      // Daily news digest hour (SA time, -1 = off)

input group "5 · Notifications"
input bool   InpPush            = true;   // MT5 phone app push (needs MetaQuotes ID)
input string InpNtfyTopic       = "";     // ntfy topic (same as your AURA app)
input bool   InpPopup           = true;   // Pop-up alert on the PC
input bool   InpSound           = true;   // Sound on the PC
input bool   InpHeartbeat       = true;   // Tell the cloud backup this PC is online

input group "6 · Chart"
input bool   InpPanel           = true;   // Info panel (top left)
input bool   InpDraw            = true;   // Draw entry / SL / TP and news levels

//──────────────────────────────── types ─────────────────────────────
struct Eng
  {
   bool              on, ready, isNews;
   ENUM_TIMEFRAMES   tf;
   string            lbl, status;
   int               fast, slow, trend;
   double            rr;
   // indicator state (Pine/Python compatible: SMA-seeded EMA, RMA ATR)
   int               cnt;
   double            sumF, sumS, sumT, sumA;
   double            ef, es, et, atr, efPrev, esPrev;
   bool              efOk, esOk, etOk, atrOk, prevOk;
   double            prevClose;
   bool              hasPrev;
   double            lastClose;
   // open trade
   int               pos;
   double            entry, sl, risk, tp1, tp2, tp3, rejLvl;
   bool              t1, t2, rej, warnOn, hasTp1, hasTp2;
   datetime          entryBar;      // open time of the signal candle
   double            lots, riskPct, riskMoney;
   bool              noEdge;
   string            advice;
   // track record
   int               nT, nW;
   double            sumW, sumL, eqR, peak, maxdd;
   datetime          lastBar, firstBar;
  };

struct News
  {
   ulong             vid, eid;
   datetime          t;             // server time
   string            name, cur;
   int               imp;           // 3 high, 2 medium
   bool              hasF, hasP, hasA;
   double            f, p, a;
   int               impact;        // 0 n/a, 1 positive for currency, 2 negative
   int               unit, mult, digits;
   int               stage;         // last warning sent: 0, 60, 15, 5
   bool              started, relSent, brkDone, digestOk;
   double            rHi, rLo, rBuf;
  };

#define E_M5   0
#define E_M15  1
#define E_D1   2
#define E_NEWS 3
#define NE     4

Eng      E[NE];
News     N[];
datetime g_newsTimes[];                // high-impact times (server) for the pause filter
string   g_acc = "", g_zarSym = "";
ulong    g_calChange = 0;
datetime g_lastNewsRefresh = 0, g_lastHb = 0;
int      g_lastDigestDay = -1;
bool     g_webWarned = false, g_isTester = false;
string   g_pushQ[];
ulong    g_pushTimes[10];
int      g_pushIdx = 0;
ulong    g_lastPushMs = 0;
string   g_log[8];
int      g_logN = 0;
datetime g_startedAt = 0;

//──────────────────────────────── small helpers ─────────────────────
string Px(double v)   { return DoubleToString(v, _Digits); }
string F2(double v)   { return DoubleToString(v, 2); }
string Sgn(double v, int d = 2) { return (v >= 0 ? "+" : "") + DoubleToString(v, d); }

double SaOffset()     // seconds to add to server time to get South African time (UTC+2)
  {
   long off = (long)(TimeTradeServer() - TimeGMT());
   off = (long)MathRound(off / 1800.0) * 1800;
   return (double)(7200 - off);
  }
datetime ToSA(datetime serverT) { return (datetime)(serverT + (long)SaOffset()); }
string HHMM(datetime t)
  {
   MqlDateTime d; TimeToStruct(t, d);
   return StringFormat("%02d:%02d", d.hour, d.min);
  }
string SATime(datetime serverT) { return HHMM(ToSA(serverT)); }
string DayName(int dow)
  {
   string n[7] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
   return n[dow % 7];
  }

bool Once(string key)  // persistent de-duplication across restarts / timeframe changes
  {
   string gv = "AURA_" + key;
   if(StringLen(gv) > 63) gv = StringSubstr(gv, 0, 63);
   if(GlobalVariableCheck(gv)) return false;
   GlobalVariableSet(gv, (double)TimeCurrent());
   return true;
  }

void AddLog(string s)
  {
   for(int i = 7; i > 0; i--) g_log[i] = g_log[i - 1];
   g_log[0] = SATime(TimeTradeServer()) + "  " + s;
   if(g_logN < 8) g_logN++;
  }

double Spread() { return SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID); }

//──────────────────────────────── money / lots ──────────────────────
void FindZar()
  {
   g_zarSym = "";
   int tot = SymbolsTotal(false);
   for(int i = 0; i < tot; i++)
     {
      string s = SymbolName(i, false);
      if(StringFind(s, "USDZAR") == 0) { g_zarSym = s; SymbolSelect(s, true); break; }
     }
  }
double UsdZar()
  {
   if(g_zarSym == "") return 0;
   double b = SymbolInfoDouble(g_zarSym, SYMBOL_BID);
   return b > 0 ? b : 0;
  }
double ToZar(double accMoney)
  {
   string a = g_acc; StringToUpper(a);
   if(a == "ZAR") return accMoney;
   double fx = UsdZar();
   if(fx <= 0) return -1;
   if(a == "USC") return accMoney / 100.0 * fx;
   if(a == "USD") return accMoney * fx;
   return -1;
  }
string Money(double accMoney)
  {
   string s = DoubleToString(accMoney, 2) + " " + g_acc;
   string a = g_acc; StringToUpper(a);
   if(a != "ZAR")
     {
      double z = ToZar(accMoney);
      if(z > 0) s += " ≈ R" + DoubleToString(z, 2);
     }
   return s;
  }
double LossPerLot(double dist)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv <= 0) tv = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(ts <= 0 || tv <= 0) return 0;
   return dist / ts * tv;
  }
double CalcLots(double dist, double riskPct, double &riskMoney)
  {
   riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * riskPct / 100.0;
   double lpl = LossPerLot(dist);
   if(lpl <= 0 || riskPct <= 0) return 0;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(step <= 0) step = 0.01;
   double lots = MathFloor(riskMoney / lpl / step + 1e-9) * step;
   if(vmax > 0 && lots > vmax) lots = vmax;
   return NormalizeDouble(lots, 2);
  }
string LotText(double lots)
  {
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(lots < vmin - 1e-9) return "below the minimum " + DoubleToString(vmin, 2) + ": SKIP (stop too wide for this balance)";
   return DoubleToString(lots, 2) + " lots";
  }

//──────────────────────────────── notifications ─────────────────────
void SendNtfy(string title, string body, string tags, string priority)
  {
   if(InpNtfyTopic == "" || g_isTester) return;
   string url = "https://ntfy.sh/" + InpNtfyTopic;
   string hdr = "Title: " + title + "\r\nTags: " + tags + "\r\nPriority: " + priority +
                "\r\nClick: https://waizyk.github.io/aura/\r\nIcon: https://waizyk.github.io/aura/icon-192.png\r\n";
   char data[], res[]; string rh;
   int n = StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(n > 0) ArrayResize(data, n - 1);           // drop the trailing \0
   ResetLastError();
   int code = WebRequest("POST", url, hdr, 4000, data, res, rh);
   if(code == -1 && !g_webWarned)
     {
      g_webWarned = true;
      Print("AURA: ntfy blocked (error ", GetLastError(), "). Add https://ntfy.sh in Tools > Options > Expert Advisors > 'Allow WebRequest for listed URL'.");
     }
  }

void Heartbeat()
  {
   if(!InpHeartbeat || InpNtfyTopic == "" || g_isTester) return;
   string url = "https://ntfy.sh/" + InpNtfyTopic + "-hb";
   string body = "alive " + _Symbol + " " + TimeToString(TimeGMT(), TIME_DATE | TIME_MINUTES);
   char data[], res[]; string rh;
   int n = StringToCharArray(body, data, 0, WHOLE_ARRAY, CP_UTF8);
   if(n > 0) ArrayResize(data, n - 1);
   WebRequest("POST", url, "Priority: min\r\n", 3000, data, res, rh);
  }

void QueuePush(string msg)
  {
   if(!InpPush || g_isTester) return;
   if(StringLen(msg) > 250) msg = StringSubstr(msg, 0, 250);
   int n = ArraySize(g_pushQ);
   if(n >= 30) return;
   ArrayResize(g_pushQ, n + 1);
   g_pushQ[n] = msg;
  }
void FlushPush()  // MT5 limit: max 2 per second and 10 per minute
  {
   if(ArraySize(g_pushQ) == 0) return;
   ulong now = GetTickCount64();
   if(now - g_lastPushMs < 1200) return;
   ulong oldest = g_pushTimes[g_pushIdx];
   if(oldest != 0 && now - oldest < 61000) return;
   if(!SendNotification(g_pushQ[0]))
      Print("AURA: push failed (", GetLastError(), "). Set your MetaQuotes ID in Tools > Options > Notifications.");
   g_pushTimes[g_pushIdx] = now; g_pushIdx = (g_pushIdx + 1) % 10; g_lastPushMs = now;
   int n = ArraySize(g_pushQ);
   for(int i = 1; i < n; i++) g_pushQ[i - 1] = g_pushQ[i];
   ArrayResize(g_pushQ, n - 1);
  }

void Notify(string title, string body, string shortMsg, string tags, string priority)
  {
   AddLog(shortMsg);
   Print("AURA | ", shortMsg);
   if(g_isTester) return;
   SendNtfy(title, body + "\n\nAURA by ACE TECH", tags, priority);
   QueuePush(shortMsg);
   if(InpPopup) Alert(shortMsg);
   else if(InpSound) PlaySound("alert.wav");
  }

//──────────────────────────────── news pause filter ─────────────────
ulong g_impIds[]; int g_impVal[];
int EventImportance(ulong eid, string &name, int &unit, int &mult, int &digits)
  {
   MqlCalendarEvent ev;
   if(!CalendarEventById(eid, ev)) return -1;
   name = ev.name; unit = (int)ev.unit; mult = (int)ev.multiplier; digits = (int)ev.digits;
   return (int)ev.importance;
  }
int ImportanceCached(ulong eid)
  {
   int n = ArraySize(g_impIds);
   for(int i = 0; i < n; i++) if(g_impIds[i] == eid) return g_impVal[i];
   string nm; int u, m, d;
   int imp = EventImportance(eid, nm, u, m, d);
   ArrayResize(g_impIds, n + 1); ArrayResize(g_impVal, n + 1);
   g_impIds[n] = eid; g_impVal[n] = imp;
   return imp;
  }
bool WantImportance(int imp)
  {
   return imp == (int)CALENDAR_IMPORTANCE_HIGH || (InpNewsMedium && imp == (int)CALENDAR_IMPORTANCE_MODERATE);
  }
void LoadNewsTimes(datetime from)
  {
   ArrayResize(g_newsTimes, 0);
   if(!InpNewsOn || g_isTester) return;
   string cur[]; int nc = StringSplit(InpNewsCurrencies, ',', cur);
   for(int c = 0; c < nc; c++)
     {
      string cc = cur[c]; StringTrimLeft(cc); StringTrimRight(cc); StringToUpper(cc);
      if(cc == "") continue;
      MqlCalendarValue v[];
      int n = CalendarValueHistory(v, from, TimeTradeServer() + 7 * 86400, NULL, cc);
      for(int i = 0; i < n; i++)
        {
         if(!WantImportance(ImportanceCached(v[i].event_id))) continue;
         int k = ArraySize(g_newsTimes);
         ArrayResize(g_newsTimes, k + 1);
         g_newsTimes[k] = v[i].time;
        }
     }
   ArraySort(g_newsTimes);
  }
bool NewsPausedAt(datetime t)
  {
   int n = ArraySize(g_newsTimes);
   for(int i = 0; i < n; i++)
      if((long)t >= (long)g_newsTimes[i] - InpPauseBefore * 60 && (long)t <= (long)g_newsTimes[i] + InpPauseAfter * 60) return true;
   return false;
  }

//──────────────────────────────── engine ────────────────────────────
void ResetState(Eng &e)
  {
   e.ready = false; e.status = "loading";
   e.cnt = 0; e.sumF = 0; e.sumS = 0; e.sumT = 0; e.sumA = 0;
   e.ef = 0; e.es = 0; e.et = 0; e.atr = 0; e.efPrev = 0; e.esPrev = 0;
   e.efOk = false; e.esOk = false; e.etOk = false; e.atrOk = false; e.prevOk = false;
   e.prevClose = 0; e.hasPrev = false; e.lastClose = 0;
   e.pos = 0; e.entry = 0; e.sl = 0; e.risk = 0; e.tp1 = 0; e.tp2 = 0; e.tp3 = 0; e.rejLvl = 0;
   e.t1 = false; e.t2 = false; e.rej = false; e.warnOn = false; e.hasTp1 = false; e.hasTp2 = false;
   e.entryBar = 0; e.lots = 0; e.riskPct = 0; e.riskMoney = 0; e.noEdge = false;
   e.advice = "WAIT for a signal";
   e.nT = 0; e.nW = 0; e.sumW = 0; e.sumL = 0; e.eqR = 0; e.peak = 0; e.maxdd = 0;
   e.lastBar = 0; e.firstBar = 0;
  }

void Setup(int i, bool on, ENUM_TIMEFRAMES tf, string lbl, int f, int s, int t, double rr, bool isNews)
  {
   E[i].on = on; E[i].tf = tf; E[i].lbl = lbl; E[i].fast = f; E[i].slow = s; E[i].trend = t; E[i].rr = rr; E[i].isNews = isNews;
   ResetState(E[i]);
  }

void AvgStep(double &v, bool &ok, double &sum, int cnt, int n, double x, bool rma)
  {
   if(!ok)
     {
      sum += x;
      if(cnt >= n) { v = sum / n; ok = true; }
      return;
     }
   if(rma) v = (v * (n - 1) + x) / n;
   else    v = (2.0 / (n + 1)) * x + (1.0 - 2.0 / (n + 1)) * v;
  }

void IndUpdate(Eng &e, const MqlRates &b)
  {
   double tr = e.hasPrev ? MathMax(b.high - b.low, MathMax(MathAbs(b.high - e.prevClose), MathAbs(b.low - e.prevClose))) : b.high - b.low;
   e.prevOk = e.efOk && e.esOk;
   e.efPrev = e.ef; e.esPrev = e.es;
   e.cnt++;
   AvgStep(e.ef, e.efOk, e.sumF, e.cnt, e.fast, b.close, false);
   AvgStep(e.es, e.esOk, e.sumS, e.cnt, e.slow, b.close, false);
   AvgStep(e.et, e.etOk, e.sumT, e.cnt, e.trend, b.close, false);
   AvgStep(e.atr, e.atrOk, e.sumA, e.cnt, InpAtrLen, tr, true);
   e.prevClose = b.close; e.hasPrev = true; e.lastClose = b.close;
  }

double RiskPct(Eng &e, bool &noEdge, double &kelly, bool &ready)
  {
   noEdge = false; ready = false; kelly = 0;
   if(e.nT == 0) return InpStartRiskPct;
   double wr = (double)e.nW / e.nT;
   double aw = e.nW > 0 ? e.sumW / e.nW : 0;
   double al = (e.nT - e.nW) > 0 ? e.sumL / (e.nT - e.nW) : 0;
   if(aw <= 0 || al <= 0) return InpStartRiskPct;
   double pay = aw / al;
   kelly = wr - (1 - wr) / pay;
   ready = e.nT >= InpMinTradesKelly;
   if(!ready) return InpStartRiskPct;
   if(kelly <= 0) { noEdge = true; return 0; }
   return MathMin(kelly * InpKellyFraction * 100.0, InpMaxRiskPct);
  }

string Emo(string ev)
  {
   if(ev == "BUY") return "🟢"; if(ev == "SELL") return "🔴"; if(ev == "TP1" || ev == "TP2") return "✅";
   if(ev == "TP") return "🎯"; if(ev == "SL") return "🛑"; if(ev == "REVERSE") return "🔄";
   if(ev == "WARNING") return "⚠️"; if(ev == "SKIP") return "⏸"; return "•";
  }
string Tag(string ev)
  {
   if(ev == "BUY") return "green_circle"; if(ev == "SELL") return "red_circle"; if(ev == "TP1" || ev == "TP2") return "white_check_mark";
   if(ev == "TP") return "dart"; if(ev == "SL") return "octagonal_sign"; if(ev == "REVERSE") return "arrows_counterclockwise";
   if(ev == "WARNING") return "warning"; if(ev == "SKIP") return "double_vertical_bar"; return "bell";
  }

string DailyTrendLine(int dir)
  {
   if(!E[E_D1].ready || !E[E_D1].etOk) return "";
   int d = E[E_D1].lastClose > E[E_D1].et ? 1 : -1;
   if(dir == 0) return "Daily trend: " + (d == 1 ? "UP" : "DOWN");
   return "Daily trend: " + (d == 1 ? "UP" : "DOWN") + (d == dir ? " ✅ with this trade" : " ⚠️ against this trade (be extra strict)");
  }

void SendEntry(Eng &e, string note)
  {
   string ev = e.pos == 1 ? "BUY" : "SELL";
   if(!Once(e.lbl + "_" + ev + "_" + IntegerToString((long)e.entryBar))) return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double now = e.pos == 1 ? ask : bid;
   double liveR = e.risk > 0 ? (now - e.entry) / e.risk * e.pos : 0;
   bool late = liveR > InpLateEntryR || liveR < -0.5;
   string lot = e.noEdge ? "SKIP (Kelly: no edge on " + e.lbl + " right now)" : LotText(e.lots);
   string b = Emo(ev) + " AURA ⚡ LIVE · " + ev + " · " + _Symbol + " " + e.lbl + "\n";
   b += "Entry: " + Px(e.entry) + "  (" + (e.pos == 1 ? "Ask " : "Bid ") + Px(now) + " now)\n";
   b += "SL: " + Px(e.sl) + "  ($" + F2(e.risk) + " away)\n";
   if(e.hasTp1) b += "TP1: " + Px(e.tp1) + (e.hasTp2 ? "  TP2: " + Px(e.tp2) : "") + "\n";
   b += "Final TP (" + DoubleToString(e.rr, 1) + "R): " + Px(e.tp3) + "\n";
   b += "Lot: " + lot + "\n";
   b += "Risk: " + Money(e.riskMoney) + " (" + F2(e.riskPct) + "%)\n";
   b += "Spread now: $" + F2(Spread()) + (Spread() > InpMaxSpreadUsd ? " ⚠️ wide" : "") + "\n";
   string dl = (e.tf != PERIOD_D1) ? DailyTrendLine(e.pos) : "";
   if(dl != "") b += dl + "\n";
   b += (late ? "❌ Price already moved " + Sgn(liveR) + "R: DON'T chase, wait for the next one" : "✅ Enterable now") + "\n";
   b += note + "\nCandle closed " + SATime(e.entryBar + PeriodSeconds(e.tf)) + " SA";
   string s = "AURA " + ev + " " + e.lbl + " @" + Px(e.entry) + " SL " + Px(e.sl) + " TP " + Px(e.tp3) +
              " Lot " + (e.noEdge ? "SKIP" : DoubleToString(e.lots, 2)) + " Risk " + F2(e.riskPct) + "%" + (late ? " (late, don't chase)" : "");
   Notify("AURA " + ev + " " + e.lbl, b, s, Tag(ev), "high");
  }

void SendEvent(Eng &e, string ev, string note, double R, bool hasR)
  {
   if(!Once(e.lbl + "_" + ev + "_" + IntegerToString((long)e.entryBar))) return;
   string side = e.pos == 1 ? "LONG" : "SHORT";
   string b = Emo(ev) + " AURA · " + ev + " · " + _Symbol + " " + e.lbl + "\n";
   b += side + " from " + Px(e.entry) + "\n";
   if(hasR) b += "Result: " + Sgn(R) + "R\n";
   b += note + "\nPrice now: " + Px(SymbolInfoDouble(_Symbol, SYMBOL_BID)) + " · " + SATime(TimeTradeServer()) + " SA";
   string s = "AURA " + ev + " " + e.lbl + (hasR ? " " + Sgn(R) + "R" : "") + ": " + note;
   Notify("AURA " + ev + " " + e.lbl, b, s, Tag(ev), (ev == "REVERSE" || ev == "SL" || ev == "TP") ? "high" : "default");
  }

void CloseTrade(Eng &e, double px, string why, bool live)
  {
   if(e.pos == 0) return;
   double R = (px - e.entry) / e.risk * e.pos;
   double Rnet = R - (e.risk > 0 ? InpStatsSpread / e.risk : 0);
   if(!e.isNews)
     {
      e.nT++;
      if(Rnet > 0) { e.nW++; e.sumW += Rnet; } else e.sumL += -Rnet;
      e.eqR += Rnet; e.peak = MathMax(e.peak, e.eqR); e.maxdd = MathMax(e.maxdd, e.peak - e.eqR);
     }
   string note = why == "TP" ? "Final take profit hit: bank it" : why == "SL" ? "Stop loss hit: normal, wait for the next signal" :
                 "Opposite signal: the old trade is invalid, close it";
   string ev = why == "REV" ? "REVERSE" : why;
   if(live) SendEvent(e, ev, note, R, true);
   e.advice = why == "TP" ? "TARGET HIT: wait for the next signal" : why == "SL" ? "STOPPED OUT: wait for the next signal" : "REVERSED";
   e.pos = 0;
   if(InpDraw && live) DrawTrade(e);
  }

void OpenTrade(Eng &e, int dir, double entry, double sl, datetime barTime, bool live, double riskPctOverride)
  {
   double rk = MathAbs(entry - sl);
   if(rk <= 0) return;
   bool noEdge = false, ready = false; double kelly = 0;
   double rp = riskPctOverride > 0 ? riskPctOverride : RiskPct(e, noEdge, kelly, ready);
   e.pos = dir; e.entry = entry; e.sl = sl; e.risk = rk;
   e.hasTp1 = e.rr > 1; e.hasTp2 = e.rr > 2;
   e.tp1 = entry + dir * rk; e.tp2 = entry + dir * rk * 2; e.tp3 = entry + dir * rk * e.rr;
   e.t1 = false; e.t2 = false; e.rej = false; e.warnOn = false;
   e.entryBar = barTime; e.noEdge = noEdge; e.riskPct = rp;
   e.lots = CalcLots(rk, rp, e.riskMoney);
   e.advice = noEdge ? "SIGNAL, but Kelly says NO EDGE: skip" : "NEW TRADE: place SL and TP now, then HOLD";
  }

void ProcessBar(Eng &e, const MqlRates &b, bool live)
  {
   IndUpdate(e, b);
   if(!(e.efOk && e.esOk && e.etOk && e.atrOk && e.prevOk)) return;
   bool closed = false; double cpx = 0; string why = "";
   // ---- manage the open trade (in live mode ticks usually got there first)
   if(e.pos != 0)
     {
      if(e.pos == 1)
        {
         if(b.low <= e.sl) { closed = true; cpx = e.sl; why = "SL"; }
         else
           {
            if(e.hasTp1 && !e.t1 && b.high >= e.tp1) { e.t1 = true; if(live && InpMilestones) SendEvent(e, "TP1", "TP1 reached: trade is working, keep holding", 0, false); }
            if(e.hasTp2 && !e.t2 && b.high >= e.tp2) { e.t2 = true; if(live && InpMilestones) SendEvent(e, "TP2", "TP2 reached: keep holding for the final target", 0, false); }
            if(b.high >= e.tp3) { closed = true; cpx = e.tp3; why = "TP"; }
           }
        }
      else
        {
         if(b.high >= e.sl) { closed = true; cpx = e.sl; why = "SL"; }
         else
           {
            if(e.hasTp1 && !e.t1 && b.low <= e.tp1) { e.t1 = true; if(live && InpMilestones) SendEvent(e, "TP1", "TP1 reached: trade is working, keep holding", 0, false); }
            if(e.hasTp2 && !e.t2 && b.low <= e.tp2) { e.t2 = true; if(live && InpMilestones) SendEvent(e, "TP2", "TP2 reached: keep holding for the final target", 0, false); }
            if(b.low <= e.tp3) { closed = true; cpx = e.tp3; why = "TP"; }
           }
        }
      if(!closed)
        {
         double rng = b.high - b.low;
         bool bearRej = rng > 0 && (b.high - MathMax(b.open, b.close)) / rng * 100 >= InpRejWickPct && rng >= InpRejMinAtr * e.atr;
         bool bullRej = rng > 0 && (MathMin(b.open, b.close) - b.low) / rng * 100 >= InpRejWickPct && rng >= InpRejMinAtr * e.atr;
         bool rejConf = e.rej && (e.pos == 1 ? b.close < e.rejLvl : b.close > e.rejLvl);
         bool broken = e.pos == 1 ? b.close < e.es : b.close > e.es;
         if(rejConf || broken)
           {
            e.advice = rejConf ? "HOLD (warning: rejection confirmed)" : "HOLD (warning: closed past slow EMA)";
            if(!e.warnOn && live && InpWarnings) SendEvent(e, "WARNING", e.advice + ". Keep SL where it is; consider partial profit if in profit.", 0, false);
            e.warnOn = true;
           }
         else
           {
            e.warnOn = false;
            bool newRej = e.pos == 1 ? bearRej : bullRej;
            bool weak = e.pos == 1 ? b.close < e.ef : b.close > e.ef;
            e.advice = newRej ? "CAUTION: rejection candle, watch next close" : (weak ? "HOLD: pullback inside trend" : "HOLD: trend intact, let it run");
           }
         e.rej = e.pos == 1 ? bearRej : bullRej;
         e.rejLvl = e.pos == 1 ? b.low : b.high;
        }
     }
   // ---- signals
   bool crossUp = e.ef > e.es && e.efPrev <= e.esPrev;
   bool crossDn = e.ef < e.es && e.efPrev >= e.esPrev;
   double slL = b.low - e.atr * InpSlAtrBuf, slS = b.high + e.atr * InpSlAtrBuf;
   bool buy  = crossUp && (!InpConfirm || b.close > b.open) && b.close > e.et;
   bool sell = crossDn && (!InpConfirm || b.close < b.open) && b.close < e.et;
   if(!closed && ((buy && e.pos == -1) || (sell && e.pos == 1))) { closed = true; cpx = b.close; why = "REV"; }
   if(closed && e.pos != 0) CloseTrade(e, cpx, why, live);
   // ---- new entry (skipped inside the news window)
   int nd = buy ? 1 : (sell ? -1 : 0);
   if(nd != 0 && e.pos == 0)
     {
      datetime closeT = b.time + PeriodSeconds(e.tf);
      if(e.tf != PERIOD_D1 && NewsPausedAt(closeT))
        {
         if(live && Once(e.lbl + "_SKIP_" + IntegerToString((long)b.time)))
            Notify("AURA paused " + e.lbl, "⏸ AURA · " + (nd == 1 ? "BUY" : "SELL") + " signal on " + e.lbl + " SKIPPED\nHigh-impact news window: spreads and slippage are too big for a normal entry. Wait for the news breakout alert instead.",
                   "AURA " + e.lbl + " " + (nd == 1 ? "BUY" : "SELL") + " skipped: news window", "double_vertical_bar", "default");
         return;
        }
      OpenTrade(e, nd, b.close, nd == 1 ? slL : slS, b.time, live, 0);
      if(live) { SendEntry(e, e.advice); if(InpDraw) DrawTrade(e); }
     }
  }

void TickManage(Eng &e)
  {
   if(e.pos == 0 || !e.ready) return;
   double px = e.pos == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(px <= 0) return;
   int d = e.pos;
   if((d == 1 && px <= e.sl) || (d == -1 && px >= e.sl)) { CloseTrade(e, e.sl, "SL", true); return; }
   if(e.hasTp1 && !e.t1 && (px - e.tp1) * d >= 0) { e.t1 = true; if(InpMilestones) SendEvent(e, "TP1", "TP1 reached: trade is working, keep holding", 0, false); }
   if(e.hasTp2 && !e.t2 && (px - e.tp2) * d >= 0) { e.t2 = true; if(InpMilestones) SendEvent(e, "TP2", "TP2 reached: keep holding for the final target", 0, false); }
   if((px - e.tp3) * d >= 0) CloseTrade(e, e.tp3, "TP", true);
  }

bool LoadHistory(Eng &e)
  {
   int want = e.tf == PERIOD_M5 ? 20000 : (e.tf == PERIOD_M15 ? 10000 : 3000);
   int avail = Bars(_Symbol, e.tf);
   if(avail <= e.trend + 60) { e.status = "loading history (" + IntegerToString(avail) + " bars)"; return false; }
   int cnt = MathMin(want, avail - 1);
   MqlRates r[];
   int got = CopyRates(_Symbol, e.tf, 1, cnt, r);
   if(got < e.trend + 60) { e.status = "loading history (" + IntegerToString(got) + " bars)"; return false; }
   ResetState(e);
   for(int i = 0; i < got; i++) ProcessBar(e, r[i], false);
   e.firstBar = r[0].time; e.lastBar = r[got - 1].time; e.ready = true; e.status = "live";
   // a signal on the candle that just closed (EA started right after it)
   if(e.pos != 0 && e.entryBar == e.lastBar && (long)TimeCurrent() - (long)(e.lastBar + PeriodSeconds(e.tf)) <= PeriodSeconds(e.tf))
      SendEntry(e, e.advice);
   if(InpDraw) DrawTrade(e);
   return true;
  }

void CheckNewBars(Eng &e)
  {
   if(!e.ready) { LoadHistory(e); return; }
   datetime cur = iTime(_Symbol, e.tf, 0);
   if(cur == 0 || cur <= e.lastBar + PeriodSeconds(e.tf) - 1) return;
   MqlRates r[];
   int got = CopyRates(_Symbol, e.tf, e.lastBar + 1, cur - 1, r);
   if(got <= 0) return;
   for(int i = 0; i < got; i++)
     {
      if(r[i].time <= e.lastBar) continue;
      bool fresh = (long)TimeCurrent() - (long)(r[i].time + PeriodSeconds(e.tf)) <= 2 * PeriodSeconds(e.tf) + 60;
      ProcessBar(e, r[i], fresh);
      e.lastBar = r[i].time;
     }
  }

//──────────────────────────────── news engine ───────────────────────
string FmtVal(const News &n, double v)
  {
   string s = DoubleToString(v, n.digits);
   if(n.mult == CALENDAR_MULTIPLIER_THOUSANDS) s += "K";
   else if(n.mult == CALENDAR_MULTIPLIER_MILLIONS) s += "M";
   else if(n.mult == CALENDAR_MULTIPLIER_BILLIONS) s += "B";
   else if(n.mult == CALENDAR_MULTIPLIER_TRILLIONS) s += "T";
   if(n.unit == CALENDAR_UNIT_PERCENT) s += "%";
   return s;
  }

int HigherIsGoodForCurrency(string name)   // +1 normal, -1 inverse (unemployment, jobless claims)
  {
   string s = name; StringToLower(s);
   if(StringFind(s, "unemployment") >= 0 || StringFind(s, "jobless") >= 0 || StringFind(s, "claims") >= 0) return -1;
   return 1;
  }

int GoldDirFromResult(const News &n)        // +1 gold up, -1 gold down, 0 unknown
  {
   if(!n.hasA) return 0;
   int curDir = 0;
   if(n.impact == 1) curDir = 1; else if(n.impact == 2) curDir = -1;
   else if(n.hasF && n.a != n.f) curDir = (n.a > n.f ? 1 : -1) * HigherIsGoodForCurrency(n.name);
   if(curDir == 0) return 0;
   if(n.cur == "USD") return -curDir;      // stronger dollar = weaker gold
   return 0;
  }

int FindNews(ulong vid)
  {
   for(int i = 0; i < ArraySize(N); i++) if(N[i].vid == vid) return i;
   return -1;
  }

void ApplyValue(News &n, const MqlCalendarValue &v)
  {
   n.t = v.time;
   n.hasF = v.forecast_value != LONG_MIN; if(n.hasF) n.f = v.forecast_value / 1000000.0;
   n.hasP = v.prev_value != LONG_MIN;     if(n.hasP) n.p = v.prev_value / 1000000.0;
   if(v.revised_prev_value != LONG_MIN) { n.hasP = true; n.p = v.revised_prev_value / 1000000.0; }
   bool hadA = n.hasA;
   n.hasA = v.actual_value != LONG_MIN;   if(n.hasA) n.a = v.actual_value / 1000000.0;
   n.impact = (int)v.impact_type;
   if(!hadA && n.hasA) ReleaseAlert(n);
  }

void RefreshNews()
  {
   if(!InpNewsOn || g_isTester) return;
   string cur[]; int nc = StringSplit(InpNewsCurrencies, ',', cur);
   datetime now = TimeTradeServer();
   for(int c = 0; c < nc; c++)
     {
      string cc = cur[c]; StringTrimLeft(cc); StringTrimRight(cc); StringToUpper(cc);
      if(cc == "") continue;
      MqlCalendarValue v[];
      int n = CalendarValueHistory(v, now - 6 * 3600, now + 7 * 86400, NULL, cc);
      for(int i = 0; i < n; i++)
        {
         if(!WantImportance(ImportanceCached(v[i].event_id))) continue;
         int k = FindNews(v[i].id);
         if(k < 0)
           {
            string nm; int un = 0, mu = 0, dg = 0;
            int imp = EventImportance(v[i].event_id, nm, un, mu, dg);
            k = ArraySize(N); ArrayResize(N, k + 1);
            N[k].vid = v[i].id; N[k].eid = v[i].event_id; N[k].name = nm; N[k].cur = cc;
            N[k].imp = imp == (int)CALENDAR_IMPORTANCE_HIGH ? 3 : 2;
            N[k].unit = un; N[k].mult = mu; N[k].digits = dg;
            N[k].stage = 0; N[k].started = false; N[k].relSent = false; N[k].brkDone = false; N[k].digestOk = false;
            N[k].hasA = v[i].actual_value != LONG_MIN;      // already released before we started: no alerts
            N[k].relSent = N[k].hasA; N[k].a = N[k].hasA ? v[i].actual_value / 1000000.0 : 0;
            N[k].rHi = 0; N[k].rLo = 0; N[k].rBuf = 0;
            if((long)now > (long)v[i].time + InpBreakWindow * 60) { N[k].started = true; N[k].brkDone = true; N[k].stage = 5; }
           }
         ApplyValue(N[k], v[i]);
        }
     }
   // drop old items
   for(int i = ArraySize(N) - 1; i >= 0; i--)
      if((long)N[i].t < (long)now - 8 * 3600)
        {
         for(int j = i + 1; j < ArraySize(N); j++) N[j - 1] = N[j];
         ArrayResize(N, ArraySize(N) - 1);
        }
   g_lastNewsRefresh = TimeCurrent();
  }

void PollNewsChanges()   // the actual number, the second MT5 receives it
  {
   if(!InpNewsOn || g_isTester) return;
   MqlCalendarValue v[];
   int n = CalendarValueLast(g_calChange, v, NULL, NULL);
   for(int i = 0; i < n; i++)
     {
      int k = FindNews(v[i].id);
      if(k >= 0) ApplyValue(N[k], v[i]);
     }
   // belt and braces: query hot items directly
   datetime now = TimeTradeServer();
   for(int k = 0; k < ArraySize(N); k++)
      if(!N[k].hasA && (long)now >= (long)N[k].t - 5 && (long)now <= (long)N[k].t + 1800)
        {
         MqlCalendarValue one;
         if(CalendarValueById(N[k].vid, one)) ApplyValue(N[k], one);
        }
  }

double M5Atr()
  {
   if(E[E_M5].ready && E[E_M5].atrOk) return E[E_M5].atr;
   MqlRates r[]; int got = CopyRates(_Symbol, PERIOD_M5, 1, 15, r);
   if(got < 2) return 1.0;
   double s = 0; for(int i = 1; i < got; i++) s += MathMax(r[i].high - r[i].low, MathMax(MathAbs(r[i].high - r[i - 1].close), MathAbs(r[i].low - r[i - 1].close)));
   return s / (got - 1);
  }

bool PreRange(datetime t, double &hi, double &lo)
  {
   MqlRates r[];
   datetime nowS = TimeTradeServer();
   datetime from = t - InpRangeMin * 60, to = (t < nowS ? t : nowS) - 1;
   int got = CopyRates(_Symbol, PERIOD_M1, from, to, r);
   if(got <= 0) return false;
   hi = r[0].high; lo = r[0].low;
   for(int i = 1; i < got; i++) { hi = MathMax(hi, r[i].high); lo = MathMin(lo, r[i].low); }
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);     // include the forming minute
   if(TimeTradeServer() < t && bid > 0) { hi = MathMax(hi, bid); lo = MathMin(lo, bid); }
   return true;
  }

void NewsPlan(double hi, double lo, double buf, string &txt)
  {
   double atr5 = M5Atr();
   double up = hi + buf, dn = lo - buf, mid = (hi + lo) / 2;
   double dL = MathMin(MathMax(up - mid, atr5), 3 * atr5), dS = MathMin(MathMax(mid - dn, atr5), 3 * atr5);
   double rmL = 0, rmS = 0;
   double lL = CalcLots(dL, InpNewsRiskPct, rmL), lS = CalcLots(dS, InpNewsRiskPct, rmS);
   txt  = "Pre-news range: " + Px(lo) + " – " + Px(hi) + "\n";
   txt += "🟢 BUY above " + Px(up) + " · SL " + Px(up - dL) + " · TP " + Px(up + dL * InpNewsRR) + " · " + LotText(lL) + "\n";
   txt += "🔴 SELL below " + Px(dn) + " · SL " + Px(dn + dS) + " · TP " + Px(dn - dS * InpNewsRR) + " · " + LotText(lS) + "\n";
   txt += "Risk " + F2(InpNewsRiskPct) + "% (" + Money(rmL) + "). Fast option: place both as stop orders, delete the other one when one fills.";
  }

string ExpectLine(const News &n)
  {
   if(!n.hasF) return "No forecast number: trade the breakout only.";
   string s = "Forecast " + FmtVal(n, n.f) + (n.hasP ? " · Previous " + FmtVal(n, n.p) : "") + "\n";
   if(n.cur == "USD")
     {
      int g = HigherIsGoodForCurrency(n.name);
      s += "If actual > " + FmtVal(n, n.f) + " → USD " + (g == 1 ? "up" : "down") + " → GOLD likely " + (g == 1 ? "DOWN 🔴" : "UP 🟢") + "\n";
      s += "If actual < " + FmtVal(n, n.f) + " → USD " + (g == 1 ? "down" : "up") + " → GOLD likely " + (g == 1 ? "UP 🟢" : "DOWN 🔴");
      if(n.hasP && n.f != n.p)
        {
         int lean = (n.f > n.p ? 1 : -1) * g;   // +1: market expects USD-positive change
         s += "\nMarket expects a " + (lean == 1 ? "stronger" : "weaker") + " dollar than last time, so gold may drift " + (lean == 1 ? "lower" : "higher") + " before the release.";
        }
     }
   return s;
  }

string OpenTradesLine()
  {
   string s = "";
   for(int i = 0; i < NE; i++)
     {
      if(!E[i].on && i != E_NEWS) continue;
      if(E[i].pos == 0) continue;
      double px = E[i].pos == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double r = (px - E[i].entry) / E[i].risk * E[i].pos;
      s += E[i].lbl + " " + (E[i].pos == 1 ? "BUY" : "SELL") + " " + Sgn(r) + "R; ";
     }
   if(s == "") return "No open AURA trades.";
   return "Open trades: " + s + "consider banking profit or moving SL to entry before the release.";
  }

void ReleaseAlert(News &n)
  {
   if(n.relSent) return;
   n.relSent = true;
   if(!Once("N_" + IntegerToString((long)n.vid) + "_REL")) return;
   int g = GoldDirFromResult(n);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string b = "📰 AURA NEWS RESULT · " + n.cur + " " + n.name + "\n";
   b += "Actual " + FmtVal(n, n.a) + (n.hasF ? " vs Forecast " + FmtVal(n, n.f) : "") + (n.hasP ? " (Prev " + FmtVal(n, n.p) + ")" : "") + "\n";
   if(g == -1) b += "→ BETTER for USD → GOLD BEARISH 🔴\n";
   else if(g == 1) b += "→ WORSE for USD → GOLD BULLISH 🟢\n";
   else b += "→ In line / unclear: let price decide\n";
   if(n.started && n.rHi > 0)
      b += "Gold " + Px(bid) + " · range " + Px(n.rLo) + " – " + Px(n.rHi) + ". Breakout alert follows if it breaks out.";
   string s = "AURA NEWS " + n.name + ": " + FmtVal(n, n.a) + (n.hasF ? " vs " + FmtVal(n, n.f) : "") + (g == -1 ? " GOLD BEARISH" : g == 1 ? " GOLD BULLISH" : "");
   Notify("AURA NEWS RESULT", b, s, "newspaper", "high");
  }

void NewsWarn(News &n, int stage)
  {
   if(!Once("N_" + IntegerToString((long)n.vid) + "_W" + IntegerToString(stage))) return;
   long secs = (long)n.t - (long)TimeTradeServer();
   int mins = (int)(secs > 0 ? secs / 60 : 0);
   string b = "📅 AURA NEWS IN " + IntegerToString(mins) + " MIN\n" + n.cur + " · " + n.name + (n.imp == 3 ? " (HIGH impact)" : " (medium)") + "\n";
   b += "Time: " + SATime(n.t) + " SA\n" + ExpectLine(n) + "\n";
   b += "AURA pauses normal signals " + SATime(n.t - InpPauseBefore * 60) + "–" + SATime(n.t + InpPauseAfter * 60) + " SA.\n";
   if(stage <= 15)
     {
      double hi, lo;
      if(PreRange(n.t, hi, lo)) { string plan; NewsPlan(hi, lo, InpBreakBufAtr * M5Atr(), plan); b += plan + (stage == 15 ? " (levels update at the release)" : "") + "\n"; }
     }
   if(stage == 5) b += "Spreads widen now. Don't enter in the first seconds by hand; AURA alerts the breakout the moment it happens.\n";
   b += OpenTradesLine();
   string s = "AURA NEWS in " + IntegerToString(mins) + "m: " + n.name + " " + SATime(n.t) + " SA" + (n.hasF ? " F " + FmtVal(n, n.f) : "") + (n.hasP ? " P " + FmtVal(n, n.p) : "");
   Notify("AURA NEWS in " + IntegerToString(mins) + " min", b, s, "calendar", stage == 60 ? "default" : "high");
  }

void NewsStart(News &n)
  {
   n.started = true;
   double hi, lo;
   if(!PreRange(n.t, hi, lo)) { n.brkDone = true; return; }
   n.rHi = hi; n.rLo = lo; n.rBuf = InpBreakBufAtr * M5Atr();
   if(InpDraw) DrawNews(n);
   if(!Once("N_" + IntegerToString((long)n.vid) + "_LIVE")) return;
   string plan; NewsPlan(hi, lo, n.rBuf, plan);
   string b = "🔴 AURA NEWS LIVE NOW · " + n.cur + " " + n.name + "\n" + plan + "\nWatching for the breakout for " + IntegerToString(InpBreakWindow) + " min…";
   Notify("AURA NEWS LIVE", b, "AURA NEWS LIVE: " + n.name + " BUY>" + Px(hi + n.rBuf) + " SELL<" + Px(lo - n.rBuf), "rotating_light", "high");
  }

void NewsBreakout(News &n)
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int dir = 0;
   double mid0 = (bid + ask) / 2;                // mid price: a spread blow-out alone can't trigger it
   if(mid0 > n.rHi + n.rBuf) dir = 1; else if(mid0 < n.rLo - n.rBuf) dir = -1;
   if(dir == 0) return;
   n.brkDone = true;
   if(!Once("N_" + IntegerToString((long)n.vid) + "_BRK")) return;
   double atr5 = M5Atr(), mid = (n.rHi + n.rLo) / 2;
   double entry = dir == 1 ? ask : bid;
   double dist = MathMin(MathMax(MathAbs(entry - mid), atr5), 3 * atr5);
   E[E_NEWS].rr = InpNewsRR;
   OpenTrade(E[E_NEWS], dir, entry, entry - dir * dist, TimeCurrent(), true, InpNewsRiskPct);
   E[E_NEWS].ready = true;
   int g = GoldDirFromResult(n);
   string conf = g == 0 ? "Data: no clear surprise yet. Smaller size or skip." : (g == dir ? "✅ Data agrees with this move" : "⚠️ Data DISAGREES: likely a fake-out, skip it");
   double sp = Spread();
   string ev = dir == 1 ? "BUY" : "SELL";
   string b = (dir == 1 ? "🟢" : "🔴") + " AURA NEWS TRADE · " + ev + " · " + _Symbol + "\n";
   b += n.name + ": broke " + (dir == 1 ? "above " + Px(n.rHi + n.rBuf) : "below " + Px(n.rLo - n.rBuf)) + "\n";
   b += "Entry: market now (" + (dir == 1 ? "Ask " : "Bid ") + Px(entry) + ")\n";
   b += "SL: " + Px(E[E_NEWS].sl) + " ($" + F2(dist) + ")\n";
   b += "TP1: " + Px(E[E_NEWS].tp1) + " · Final TP (" + DoubleToString(InpNewsRR, 1) + "R): " + Px(E[E_NEWS].tp3) + "\n";
   b += "Lot: " + LotText(E[E_NEWS].lots) + " · Risk " + Money(E[E_NEWS].riskMoney) + " (" + F2(InpNewsRiskPct) + "%)\n";
   b += "Spread now: $" + F2(sp) + (sp > InpMaxSpreadUsd ? " ⚠️ wide: expect slippage, or wait for it to drop" : "") + "\n" + conf;
   string s = "AURA NEWS " + ev + " @" + Px(entry) + " SL " + Px(E[E_NEWS].sl) + " TP " + Px(E[E_NEWS].tp3) + " Lot " + DoubleToString(E[E_NEWS].lots, 2) + (g != 0 && g != dir ? " DATA DISAGREES" : "");
   Notify("AURA NEWS " + ev, b, s, dir == 1 ? "green_circle" : "red_circle", "urgent");
   if(InpDraw) DrawTrade(E[E_NEWS]);
  }

void NewsTick()
  {
   if(!InpNewsOn || g_isTester) return;
   datetime now = TimeTradeServer();
   for(int k = 0; k < ArraySize(N); k++)
     {
      if(N[k].t > now)
        {
         long left = (long)N[k].t - (long)now;
         int stage = left <= 300 ? 5 : (left <= 900 ? 15 : (left <= 3600 ? 60 : 0));
         if(stage > 0 && stage != N[k].stage) { N[k].stage = stage; NewsWarn(N[k], stage); }
        }
      else
        {
         if(!N[k].started) NewsStart(N[k]);
         bool inWin = (long)now <= (long)N[k].t + InpBreakWindow * 60;
         if(!N[k].brkDone && inWin) NewsBreakout(N[k]);
         if(!N[k].brkDone && !inWin)
           {
            N[k].brkDone = true;
            if(Once("N_" + IntegerToString((long)N[k].vid) + "_NOBRK"))
               Notify("AURA NEWS", "⏹ AURA · " + N[k].name + ": no clean breakout within " + IntegerToString(InpBreakWindow) + " min. No news trade. Normal signals resume at " + SATime(N[k].t + InpPauseAfter * 60) + " SA.",
                      "AURA NEWS: no breakout on " + N[k].name + ", no trade", "stop_button", "default");
            ObjectsDeleteAll(0, "AURA_NEWS_");
           }
        }
     }
  }

void DailyDigest()
  {
   if(!InpNewsOn || InpDigestHourSA < 0 || g_isTester) return;
   MqlDateTime d; TimeToStruct(ToSA(TimeTradeServer()), d);
   if(d.hour < InpDigestHourSA || d.day_of_week == 0 || d.day_of_week == 6) return;
   if(g_lastDigestDay == d.day_of_year) return;
   g_lastDigestDay = d.day_of_year;
   if(!Once("DIGEST_" + IntegerToString(d.year) + "_" + IntegerToString(d.day_of_year))) return;
   string list = ""; int cnt = 0;
   for(int k = 0; k < ArraySize(N); k++)
     {
      MqlDateTime nd; TimeToStruct(ToSA(N[k].t), nd);
      if(nd.day_of_year != d.day_of_year || nd.year != d.year) continue;
      list += SATime(N[k].t) + "  " + N[k].cur + " " + N[k].name + (N[k].hasF ? " · F " + FmtVal(N[k], N[k].f) : "") + (N[k].hasP ? " · P " + FmtVal(N[k], N[k].p) : "") + "\n";
      cnt++;
     }
   string b = "📅 AURA · Today's news (" + DayName(d.day_of_week) + ", SA time)\n";
   b += cnt == 0 ? "No high-impact news today. Normal AURA signals all day.\n" : list + "AURA warns you 60 / 15 / 5 min before each one.\n";
   b += "Best trading window: 14:00–18:00 SA (New York open).";
   Notify("AURA today", b, "AURA today: " + IntegerToString(cnt) + " high-impact news event(s)", "calendar", "low");
  }

//──────────────────────────────── chart ─────────────────────────────
void HLine(string name, double price, color c, ENUM_LINE_STYLE st, string text)
  {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_STYLE, st);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
  }
void DrawTrade(Eng &e)
  {
   string p = "AURA_" + e.lbl + "_";
   ObjectsDeleteAll(0, p);
   if(!InpDraw || e.pos == 0) { ChartRedraw(); return; }
   // show the chart's own timeframe, M15, and news trades
   bool show = e.isNews || e.tf == (ENUM_TIMEFRAMES)Period() || (e.tf == PERIOD_M15 && Period() != PERIOD_M5 && Period() != PERIOD_D1);
   if(!show) return;
   HLine(p + "E", e.entry, clrSilver, STYLE_DASH, "AURA " + e.lbl + " entry");
   HLine(p + "SL", e.sl, clrRed, STYLE_SOLID, "AURA " + e.lbl + " SL");
   HLine(p + "TP", e.tp3, clrLime, STYLE_SOLID, "AURA " + e.lbl + " final TP");
   if(e.hasTp1) HLine(p + "T1", e.tp1, clrMediumSeaGreen, STYLE_DOT, "AURA " + e.lbl + " TP1");
   if(e.hasTp2) HLine(p + "T2", e.tp2, clrMediumSeaGreen, STYLE_DOT, "AURA " + e.lbl + " TP2");
   ChartRedraw();
  }
void DrawNews(News &n)
  {
   HLine("AURA_NEWS_HI", n.rHi + n.rBuf, clrDodgerBlue, STYLE_DASHDOT, "AURA news BUY above");
   HLine("AURA_NEWS_LO", n.rLo - n.rBuf, clrOrangeRed, STYLE_DASHDOT, "AURA news SELL below");
   ChartRedraw();
  }

string SessionLabel()
  {
   MqlDateTime d; TimeToStruct(ToSA(TimeTradeServer()), d);
   int m = d.hour * 60 + d.min;
   bool usDst = (d.mon > 3 && d.mon < 11) || (d.mon == 3 && d.day >= 8) || (d.mon == 11 && d.day < 7);  // approx
   int nyOpen = usDst ? 14 * 60 : 15 * 60;
   if(d.day_of_week == 6 || d.day_of_week == 0) return "Market closed (weekend)";
   if(m >= nyOpen && m < nyOpen + 240) return "New York open: BEST";
   if(m >= 9 * 60 && m < nyOpen) return "London: OK";
   if(m >= nyOpen + 240 && m < nyOpen + 540) return "Late New York: weak";
   return "Asia: quiet";
  }

void Panel()
  {
   if(!InpPanel) return;
   string t = "AURA · Gold Signals   by ACE TECH · a product of ACE OPS · built by Ace Khan\n";
   t += _Symbol + "   Bid " + Px(SymbolInfoDouble(_Symbol, SYMBOL_BID)) + "   Spread $" + F2(Spread()) +
        "   Balance " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " " + g_acc + "\n";
   t += "SA " + SATime(TimeTradeServer()) + "   " + SessionLabel() + "\n";
   t += "──────────────────────────────────────────\n";
   for(int i = 0; i < 3; i++)
     {
      if(!E[i].on) continue;
      string l = StringFormat("%-4s", E[i].lbl) + ": ";
      if(!E[i].ready) { t += l + E[i].status + "\n"; continue; }
      bool ne = false, rd = false; double k = 0;
      double rp = RiskPct(E[i], ne, k, rd);
      string tr = E[i].lastClose > E[i].et ? "UP" : "DOWN";
      if(E[i].pos != 0)
        {
         double px = E[i].pos == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double r = (px - E[i].entry) / E[i].risk * E[i].pos;
         l += (E[i].pos == 1 ? "BUY " : "SELL ") + Px(E[i].entry) + "  SL " + Px(E[i].sl) + "  TP " + Px(E[i].tp3) + "  " + Sgn(r) + "R  · " + E[i].advice;
        }
      else l += "FLAT · trend " + tr + (ne ? " · NO EDGE now (signals = skip)" : "");
      double ex = E[i].nT > 0 ? E[i].eqR / E[i].nT : 0;
      l += "\n      " + IntegerToString(E[i].nT) + " trades · win " + (E[i].nT > 0 ? DoubleToString(100.0 * E[i].nW / E[i].nT, 1) : "-") + "% · exp " + Sgn(ex) + "R · max DD " + DoubleToString(E[i].maxdd, 1) + "R · risk " + F2(rp) + "%";
      t += l + "\n";
     }
   if(E[E_NEWS].pos != 0)
     {
      double px = E[E_NEWS].pos == 1 ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      t += "NEWS: " + (E[E_NEWS].pos == 1 ? "BUY " : "SELL ") + Px(E[E_NEWS].entry) + "  SL " + Px(E[E_NEWS].sl) + "  TP " + Px(E[E_NEWS].tp3) + "  " + Sgn((px - E[E_NEWS].entry) / E[E_NEWS].risk * E[E_NEWS].pos) + "R\n";
     }
   t += "──────────────────────────────────────────\n";
   if(InpNewsOn && !g_isTester)
     {
      datetime now = TimeTradeServer(); int shown = 0;
      bool paused = NewsPausedAt(now);
      t += "News: " + (paused ? "⏸ NEWS WINDOW: normal signals paused" : "clear") + "\n";
      for(int k = 0; k < ArraySize(N) && shown < 3; k++)
        {
         if((long)N[k].t < (long)now - InpBreakWindow * 60) continue;
         long left = (long)N[k].t - (long)now;
         string when = left > 0 ? (left >= 3600 ? IntegerToString(left / 3600) + "h" + StringFormat("%02d", (int)((left % 3600) / 60)) : IntegerToString(left / 60) + "m") : "LIVE";
         MqlDateTime nd; TimeToStruct(ToSA(N[k].t), nd);
         t += "  " + DayName(nd.day_of_week) + " " + SATime(N[k].t) + " SA (" + when + ")  " + N[k].cur + " " + N[k].name +
              (N[k].hasF ? "  F " + FmtVal(N[k], N[k].f) : "") + (N[k].hasP ? "  P " + FmtVal(N[k], N[k].p) : "") + (N[k].hasA ? "  A " + FmtVal(N[k], N[k].a) : "") + "\n";
         shown++;
        }
      if(shown == 0) t += "  No high-impact news in the next 7 days\n";
     }
   if(g_logN > 0)
     {
      t += "──────────────────────────────────────────\nLast alerts:\n";
      for(int i = 0; i < MathMin(g_logN, 5); i++) t += "  " + g_log[i] + "\n";
     }
   Comment(t);
  }

//──────────────────────────────── events ────────────────────────────
int OnInit()
  {
   g_isTester = (bool)MQLInfoInteger(MQL_TESTER);
   g_acc = AccountInfoString(ACCOUNT_CURRENCY);
   g_startedAt = TimeCurrent();
   FindZar();
   Setup(E_M5,   InpUseM5,  PERIOD_M5,  "M5",  InpM5Fast, InpM5Slow, InpM5Trend, InpM5RR, false);
   Setup(E_M15,  InpUseM15, PERIOD_M15, "M15", InpFast, InpSlow, InpTrend, InpRR, false);
   Setup(E_D1,   InpUseD1,  PERIOD_D1,  "D1",  InpFast, InpSlow, InpTrend, InpRR, false);
   Setup(E_NEWS, false,     PERIOD_M1,  "NEWS", 1, 1, 1, InpNewsRR, true);
   E[E_NEWS].ready = true; E[E_NEWS].status = "news";
   if(InpNewsOn && !g_isTester)
     {
      MqlCalendarValue tmp[];
      CalendarValueLast(g_calChange, tmp, NULL, NULL);   // initialise the change id
      LoadNewsTimes(TimeTradeServer() - 400 * 86400);
      RefreshNews();
     }
   for(int i = 0; i < 3; i++) if(E[i].on) LoadHistory(E[i]);
   EventSetTimer(1);
   // "online" message (not on simple timeframe switches)
   double lastReason = GlobalVariableCheck("AURA_LAST_DEINIT") ? GlobalVariableGet("AURA_LAST_DEINIT") : -1;
   double lastTime = GlobalVariableCheck("AURA_LAST_DEINIT_T") ? GlobalVariableGet("AURA_LAST_DEINIT_T") : 0;
   int lr = (int)lastReason;
   bool quickSwitch = (lr == REASON_CHARTCHANGE || lr == REASON_PARAMETERS || lr == REASON_RECOMPILE) && (double)TimeCurrent() - lastTime < 600;
   if(!quickSwitch && !g_isTester)
     {
      string tfs = (InpUseM5 ? "M5 " : "") + (InpUseM15 ? "M15 " : "") + (InpUseD1 ? "D1" : "");
      string b = "⚡ AURA live engine ONLINE (MT5, zero delay)\nSymbol: " + _Symbol + " · Timeframes: " + tfs + "\n";
      b += "Account: " + g_acc + " · balance " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
      b += "News engine: " + (InpNewsOn ? "ON (" + InpNewsCurrencies + ")" : "off") + "\nAURA by ACE TECH · a product of ACE OPS · built by Ace Khan";
      Notify("AURA online", b, "AURA live engine online: " + _Symbol + " " + tfs, "zap", "default");
     }
   Heartbeat(); g_lastHb = TimeCurrent();
   Panel();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   GlobalVariableSet("AURA_LAST_DEINIT", reason);
   GlobalVariableSet("AURA_LAST_DEINIT_T", (double)TimeCurrent());
   ObjectsDeleteAll(0, "AURA_");
   Comment("");
  }

void OnTick()
  {
   for(int i = 0; i < 3; i++) if(E[i].on) { CheckNewBars(E[i]); TickManage(E[i]); }
   TickManage(E[E_NEWS]);
   NewsTick();
  }

void OnTimer()
  {
   for(int i = 0; i < 3; i++) if(E[i].on) CheckNewBars(E[i]);
   if(InpNewsOn && !g_isTester)
     {
      PollNewsChanges();
      if((long)TimeCurrent() - (long)g_lastNewsRefresh >= 60) RefreshNews();
      static datetime lastTimes = 0;
      if((long)TimeCurrent() - (long)lastTimes >= 3600) { LoadNewsTimes(TimeTradeServer() - 3 * 86400); lastTimes = TimeCurrent(); }
      NewsTick();
      DailyDigest();
     }
   FlushPush();
   if((long)TimeCurrent() - (long)g_lastHb >= 300) { Heartbeat(); g_lastHb = TimeCurrent(); }
   Panel();
  }
//+------------------------------------------------------------------+
