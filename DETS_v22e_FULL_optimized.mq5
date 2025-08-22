//+------------------------------------------------------------------+
//|                                                  DETS_v22e_FULL |
//| ENTRY: v20 indikatori + Anchor/Zone matrica primjene             |
//| EXIT:  v21 TSL (6 inputa) + izmjene (1–5)                        |
//|       - TSL (single i košarica) se pali SAMO kad je neto profit>0|
//|       - Zone positive: okidač je DRUGI TRADE (n>=2), ne "zona"   |
//|       - Zone negative: neto profit>0 + Trigger in pips           |
//|       - TSL linije crtane na chartu                              |
//|       - ZoneTSL_Anchor FIRST/WORST/AVERAGE                       |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

CTrade        trade;
CPositionInfo pos;

//============================ STRATEGY ============================//
enum StrategyMode
{
   STRAT_ONLY_BUY = 0,
   STRAT_ONLY_SELL,
   STRAT_BUY_SELL,
   STRAT_EXIT
};

// Anchor referentna cijena košarice
enum AnchorRef { ANCHOR_FIRST = 0, ANCHOR_WORST, ANCHOR_AVERAGE };

//============================ INPUTI ==============================//
enum PositionSizeRule
{
   PS_001_PER_1000 = 0,
   PS_001_PER_1500,
   PS_001_PER_2500,
   PS_001_PER_3500,
   PS_001_PER_5000,
   PS_001_PER_7500,
   PS_001_PER_10000,
   PS_001_PER_15000,
   PS_001_PER_25000,
   PS_001_PER_50000
};

// ________________________Section_1___Trading________
input string ______________________________TRADING_ULAZI       = "___________________";
input long           MagicNumber                                          = 180022;
input StrategyMode   Strategy                                             = STRAT_BUY_SELL;


// --- Lot size controls ---
enum LotSizeMode { LOT_FIXED = 0, LOT_VARIABLE = 1 };
input LotSizeMode     LotSizeModeSelection                              = LOT_FIXED;

input double         StartLot                                             = 0.01;

input PositionSizeRule PositionSize                                     = PS_001_PER_1000;
input double         MaxLot                                               = 1.00;
input int            MaxPositions                                         = 60;
input double         LotMultiplier                                        = 1.30;

input bool           UseZoneLogic                                         = true;
// === New option: where to apply indicator filters ===
enum IndicatorsScope { INDICATORS_ALL = 0, INDICATORS_ONLY_NEGATIVE_ZONES = 1 };
input IndicatorsScope IndicatorsMode = INDICATORS_ONLY_NEGATIVE_ZONES;

input int            ZoneStepPositivePips                                 = 40;
input int            ZoneStepNegativePips                                 = 150;

// Optional: ATR-based dynamic spacing
input bool           UseATRSpacing                                        = false;
input double         ATR_Positive_Mult                                    = 1.0;   // multiplier of ATR (in pips) for positive zones
input double         ATR_Negative_Mult                                    = 2.5;   // multiplier of ATR (in pips) for negative zones
input int            ZonePos_MinPips                                      = 20;
input int            ZonePos_MaxPips                                      = 120;
input int            ZoneNeg_MinPips                                      = 80;
input int            ZoneNeg_MaxPips                                      = 300;

// Risk throttles
input int            MinSecondsBetweenAdds                                = 5;
input double         MaxExposureLotsPerSide                               = 0.0;   // 0 = disabled

//---- FILTERI (v20 logika) ---------------------------------------//
// ________________________Section_2___ZoneLogic______
input string ______________________________ZONE_LOGIC          = "___________________";
input bool           UseHTFTrendFilter                                    = false;
input ENUM_TIMEFRAMES HTF_TF                                              = PERIOD_M15;
input int            HTF_MA_Fast                                          = 5;
input int            HTF_MA_Slow                                          = 15;
input ENUM_MA_METHOD HTF_MA_Method                                        = MODE_EMA;
input ENUM_APPLIED_PRICE HTF_MA_Price                                     = PRICE_CLOSE;

input bool           UseEntryCross                                        = false;
input ENUM_TIMEFRAMES EntryTF                                             = PERIOD_CURRENT;
input int            Entry_MA_Period                                      = 20;
input ENUM_MA_METHOD Entry_MA_Method                                      = MODE_EMA;
input ENUM_APPLIED_PRICE Entry_MA_Price                                   = PRICE_CLOSE;

input bool           UseRSIFilter                                         = false;
input ENUM_TIMEFRAMES RSI_TF                                              = PERIOD_CURRENT;
input int            RSI_Period                                           = 14;
input double         RSI_BuyMax                                           = 70.0;
input double         RSI_SellMin                                          = 30.0;

input bool           UseATRFilter                                         = false;
input ENUM_TIMEFRAMES ATR_TF                                              = PERIOD_CURRENT;
input int            ATR_Period                                           = 14;
input double         ATR_MinPips                                          = 5.0;

//---- MATRICA PRIMJENE FILTERA -----------------------------------//
// ________________________Section_3___TSL____________
input string ______________________________TRAILING_STOP       = "___________________";
input bool           AnchorApply_HTFTrend                                 = true;
input bool           AnchorApply_EntryCross                               = true;
input bool           AnchorApply_RSI                                      = true;
input bool           AnchorApply_ATR                                      = true;

input bool           ZoneApply_HTFTrend                                   = false;
input bool           ZoneApply_EntryCross                                 = false;
input bool           ZoneApply_RSI                                        = false;
input bool           ZoneApply_ATR                                        = true;

//---- NOVA TSL LOGIKA – 6 inputa (ostaje) ------------------------//
// ________________________Section_4___Recovery_______
input string ______________________________RECOVERY            = "___________________";
input int            Single_TSL_Trigger                                   = 30;
input int            Single_TSL_Step                                      = 15;

input int            ZonePos_TSL_Trigger                                  = 40;
input int            ZonePos_TSL_Step                                     = 15;

input int            ZoneNeg_TSL_Trigger                                  = 50;
input int            ZoneNeg_TSL_Step                                     = 20;

// Referentna cijena košarice za trailing
input AnchorRef      ZoneTSL_Anchor                                       = ANCHOR_AVERAGE;

// Optional BE nudge once basket is > 0
input bool           UseBENudge                                           = true;
input double         BENudgePips                                          = 1.0;

//---- Ostalo ------------------------------------------------------//
// ________________________Section_5___Other__________
input string ______________________________OTHER_SETTINGS      = "___________________";
input int            SpreadFilterMaxPips                                  = 20;
input bool           UseMarginCheck                                       = true;
input bool           RequireNewBarAfterClose                              = true;
input int            SlippagePips                                         = 2;
input bool           EnableDebugPrints                                    = false;
input double         ChillOutDD_Percent                                     = 0.0;
input double         EquityProtector_Percent                                = 0.0;

//============================ GLOBAL STATE ========================//
// BUY
double   g_anchorPriceBuy        = 0.0;
bool     g_hasOpenBuy            = false;
int      g_seriesEntriesBuy      = 0;
datetime g_firstTradeM1Buy       = 0;
double   g_singlePeakPipsBuy     = 0.0;
double   g_singleLockPriceBuy    = 0.0;

bool     g_zoneActiveBuy         = false;   // aktivna košarica (n>=2)
double   g_zonePeakPipsBuy       = 0.0;
double   g_zoneLockPosBuy        = 0.0;
double   g_zoneLockNegBuy        = 0.0;

// SELL
double   g_anchorPriceSell       = 0.0;
bool     g_hasOpenSell           = false;
int      g_seriesEntriesSell     = 0;
datetime g_firstTradeM1Sell      = 0;
double   g_singlePeakPipsSell    = 0.0;
double   g_singleLockPriceSell   = 0.0;

bool     g_zoneActiveSell        = false;
double   g_zonePeakPipsSell      = 0.0;
double   g_zoneLockPosSell       = 0.0;
double   g_zoneLockNegSell       = 0.0;

// općenito
datetime g_lastTradeTime         = 0;
datetime g_lastAnchorAttemptBuy  = 0;
datetime g_lastAnchorAttemptSell = 0;
datetime g_blockReentryBarBuy    = 0;
datetime g_blockReentryBarSell   = 0;

datetime g_lastAddTimeBuy        = 0;
datetime g_lastAddTimeSell       = 0;

double   g_lastBid               = 0.0;
double   g_lastAsk               = 0.0;

// zone hash
int      g_zoneMarksBuy[2048];
int      g_zoneMarksSell[2048];

//============================ INDIKATORI (handles) ================//
int hHTF_Fast = INVALID_HANDLE;
int hHTF_Slow = INVALID_HANDLE;
int hEntryMA  = INVALID_HANDLE;
int hRSI      = INVALID_HANDLE;
int hATR      = INVALID_HANDLE;

double   g_cachedATR_Pips        = 0.0;
datetime g_cachedATR_Time        = 0;

//============================ DRAWING HELPERS =====================//
void UpdateHLine(const string name, double price, color clr)
{
   if(price<=0.0)
   {
      if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
      return;
   }
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   }
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
}
void HideHLine(const string name){ if(ObjectFind(0,name)>=0) ObjectDelete(0,name); }

//============================ MATH/ACCOUNT HELPERS ================//
double PipPoint()
{
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(digits==3 || digits==5) pt*=10.0;
   return pt;
}
double PipsToPrice(double pips){ return pips*PipPoint(); }
double PriceToPips(double diff){ return diff/PipPoint(); }

int SlippagePoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (int)MathMax(0, MathRound(PipsToPrice(SlippagePips)/point));
}
bool CanTradeNow(){ if(g_lastTradeTime==0) return true; return (TimeCurrent()-g_lastTradeTime)>=1; }
bool SpreadOK()
{
   const double spr=(SymbolInfoDouble(_Symbol,SYMBOL_ASK)-SymbolInfoDouble(_Symbol,SYMBOL_BID))/PipPoint();
   return spr <= (double)SpreadFilterMaxPips;
}
bool MarginOK(double lots, bool isSell)
{
   if(!UseMarginCheck) return true;
   double req=0;
   const double px=isSell?SymbolInfoDouble(_Symbol,SYMBOL_BID):SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   ENUM_ORDER_TYPE ot = isSell?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   if(!OrderCalcMargin(ot,_Symbol,lots,px,req)) return false;
   return AccountInfoDouble(ACCOUNT_MARGIN_FREE) >= req;
}
double LotClamp(double lot)
{
   const double minL=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   const double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   const double maxL=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   lot=MathMax(minL,MathMin(lot,MathMin(MaxLot,maxL)));
   lot=MathFloor(lot/step)*step;
   int vd=(int)MathRound(MathLog(1.0/step)/MathLog(10.0)); vd=MathMax(0,MathMin(vd,8));
   return NormalizeDouble(lot,vd);
}

double USDper001()
{
   switch(PositionSize)
   {
      case PS_001_PER_1000:  return 1000.0;
      case PS_001_PER_1500:  return 1500.0;
      case PS_001_PER_2500:  return 2500.0;
      case PS_001_PER_3500:  return 3500.0;
      case PS_001_PER_5000:  return 5000.0;
      case PS_001_PER_7500:  return 7500.0;
      case PS_001_PER_10000: return 10000.0;
      case PS_001_PER_15000: return 15000.0;
      case PS_001_PER_25000: return 25000.0;
      case PS_001_PER_50000: return 50000.0;
   }
   return 1000.0; // default fallback
}
double VariableStartLot()
{
   const double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   const double unit  = USDper001();
   double units = MathFloor(bal / unit);
   if(units < 1.0) units = 1.0; // ensure at least 0.01 lot
   const double lot = 0.01 * units;
   return lot;
}
double BaseStartLot()
{
   if(LotSizeModeSelection == LOT_FIXED) return StartLot;
   return VariableStartLot();
}
double LotForSeriesBuy(){  return LotClamp(BaseStartLot()*MathPow(LotMultiplier,g_seriesEntriesBuy)); }
double LotForSeriesSell(){ return LotClamp(BaseStartLot()*MathPow(LotMultiplier,g_seriesEntriesSell)); }

// Zone hashing
int  ZHash(int zi){ int v=zi; if(v<0) v=-v*31; return (v*1315423911)&2047; }
bool IsZoneMarkedBuy(int zi){ return g_zoneMarksBuy[ZHash(zi)]==zi; }
void MarkZoneBuy(int zi){ g_zoneMarksBuy[ZHash(zi)]=zi; }
bool IsZoneMarkedSell(int zi){ return g_zoneMarksSell[ZHash(zi)]==zi; }
void MarkZoneSell(int zi){ g_zoneMarksSell[ZHash(zi)]=zi; }

// BUY zone index po ASK
int ZoneIndexFromAsk(double ask)
{
   if(g_anchorPriceBuy<=0) return 0;
   const double eps=SymbolInfoDouble(_Symbol,SYMBOL_POINT)*0.1;
   if(ask>=g_anchorPriceBuy)
   {
      double stepPips = (double)ZoneStepPositivePips;
      if(UseATRSpacing)
      {
         double ap = MathMax(0.0, g_cachedATR_Pips);
         double dyn = ap*ATR_Positive_Mult;
         stepPips = MathMax((double)ZonePos_MinPips, MathMin((double)ZonePos_MaxPips, dyn));
      }
      const double step=PipsToPrice(stepPips); if(step<=0) return 0;
      const double d=ask-g_anchorPriceBuy; if(d+eps<step) return 0;
      return (int)MathFloor((d+eps)/step);
   }
   else
   {
      double stepPips = (double)ZoneStepNegativePips;
      if(UseATRSpacing)
      {
         double ap = MathMax(0.0, g_cachedATR_Pips);
         double dyn = ap*ATR_Negative_Mult;
         stepPips = MathMax((double)ZoneNeg_MinPips, MathMin((double)ZoneNeg_MaxPips, dyn));
      }
      const double step=PipsToPrice(stepPips); if(step<=0) return 0;
      const double d=g_anchorPriceBuy-ask; if(d+eps<step) return 0;
      return -(int)MathFloor((d+eps)/step);
   }
}


bool ShouldApplyIndicatorsForZoneIndex(int zoneIndex)
{
   // When set to ONLY_NEGATIVE_ZONES, apply filters only if zoneIndex < 0.
   // For anchor/opening trade (zoneIndex == 0) and positive zones (zoneIndex > 0),
   // skip filters so entries are unconditional.
   if(IndicatorsMode == INDICATORS_ONLY_NEGATIVE_ZONES)
      return (zoneIndex < 0);
   return true; // INDICATORS_ALL
}


// SELL zone index po BID
int ZoneIndexFromBid(double bid)
{
   if(g_anchorPriceSell<=0) return 0;
   const double eps=SymbolInfoDouble(_Symbol,SYMBOL_POINT)*0.1;
   if(bid<=g_anchorPriceSell)
   {
      double stepPips = (double)ZoneStepPositivePips;
      if(UseATRSpacing)
      {
         double ap = MathMax(0.0, g_cachedATR_Pips);
         double dyn = ap*ATR_Positive_Mult;
         stepPips = MathMax((double)ZonePos_MinPips, MathMin((double)ZonePos_MaxPips, dyn));
      }
      const double step=PipsToPrice(stepPips); if(step<=0) return 0;
      const double d=g_anchorPriceSell-bid; if(d+eps<step) return 0;
      return (int)MathFloor((d+eps)/step);
   }
   else
   {
      double stepPips = (double)ZoneStepNegativePips;
      if(UseATRSpacing)
      {
         double ap = MathMax(0.0, g_cachedATR_Pips);
         double dyn = ap*ATR_Negative_Mult;
         stepPips = MathMax((double)ZoneNeg_MinPips, MathMin((double)ZoneNeg_MaxPips, dyn));
      }
      const double step=PipsToPrice(stepPips); if(step<=0) return 0;
      const double d=bid-g_anchorPriceSell; if(d+eps<step) return 0;
      return -(int)MathFloor((d+eps)/step);
   }
}

// brojanje i VWAP prosjek
int CountBuy(double& avg)
{
   int cnt=0; double sum=0.0, lots=0.0;
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(pos.PositionType()!=POSITION_TYPE_BUY) continue;
      const double v=pos.Volume(); lots+=v; sum+=pos.PriceOpen()*v; ++cnt;
   }
   avg=(lots>0?sum/lots:0.0); return cnt;
}
int CountSell(double& avg)
{
   int cnt=0; double sum=0.0, lots=0.0;
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(pos.PositionType()!=POSITION_TYPE_SELL) continue;
      const double v=pos.Volume(); lots+=v; sum+=pos.PriceOpen()*v; ++cnt;
   }
   avg=(lots>0?sum/lots:0.0); return cnt;
}

double TotalLots(bool buySide)
{
   double lots=0.0;
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(buySide && pos.PositionType()!=POSITION_TYPE_BUY) continue;
      if(!buySide && pos.PositionType()!=POSITION_TYPE_SELL) continue;
      lots += pos.Volume();
   }
   return lots;
}

void RebuildStateFromExistingPositions()
{
   // Rebuild BUY side
   double avgB=0.0; int nBuy=CountBuy(avgB);
   g_hasOpenBuy = (nBuy>0);
   g_seriesEntriesBuy = nBuy;
   if(nBuy>0)
   {
      datetime earliestTime = 0; double earliestPrice = 0.0; bool has=false;
      for(int i=0;i<PositionsTotal();++i)
      {
         if(!pos.SelectByIndex(i)) continue;
         if(pos.Symbol()!=_Symbol) continue;
         if((long)pos.Magic()!=(long)MagicNumber) continue;
         if(pos.PositionType()!=POSITION_TYPE_BUY) continue;
         datetime t=(datetime)pos.Time(); double o=pos.PriceOpen();
         if(!has || t<earliestTime){ earliestTime=t; earliestPrice=o; has=true; }
      }
      if(has) g_anchorPriceBuy = earliestPrice;
      MarkZoneBuy(0);
      // Mark zones for all existing BUY positions relative to anchor
      for(int i=0;i<PositionsTotal();++i)
      {
         if(!pos.SelectByIndex(i)) continue;
         if(pos.Symbol()!=_Symbol) continue;
         if((long)pos.Magic()!=(long)MagicNumber) continue;
         if(pos.PositionType()!=POSITION_TYPE_BUY) continue;
         int zi = ZoneIndexFromAsk(pos.PriceOpen());
         MarkZoneBuy(zi);
      }
      if(nBuy==1)
      {
         double open=0.0; if(GetSingleBuy(open))
         {
            double bid=(g_lastBid>0.0?g_lastBid:SymbolInfoDouble(_Symbol,SYMBOL_BID));
            g_singlePeakPipsBuy = MathMax(0.0, PriceToPips(bid-open));
            g_singleLockPriceBuy = 0.0;
         }
         g_zoneActiveBuy=false; g_zonePeakPipsBuy=0.0; g_zoneLockPosBuy=0.0; g_zoneLockNegBuy=0.0;
      }
      else // nBuy >= 2
      {
         g_zoneActiveBuy=true;
         double ref=ZoneRefPriceBuy();
         if(ref>0.0)
         {
            double bid=(g_lastBid>0.0?g_lastBid:SymbolInfoDouble(_Symbol,SYMBOL_BID));
            g_zonePeakPipsBuy = MathMax(0.0, PriceToPips(bid-ref));
         }
         g_zoneLockPosBuy=0.0; g_zoneLockNegBuy=0.0;
         g_singlePeakPipsBuy=0.0; g_singleLockPriceBuy=0.0;
      }
      g_firstTradeM1Buy = 0; // avoid same-bar gating after restart
      g_lastAddTimeBuy = (datetime)(TimeCurrent() - MinSecondsBetweenAdds);
   }
   else
   {
      g_anchorPriceBuy=0.0; g_firstTradeM1Buy=0; g_singlePeakPipsBuy=0.0; g_singleLockPriceBuy=0.0;
      g_zoneActiveBuy=false; g_zonePeakPipsBuy=0.0; g_zoneLockPosBuy=0.0; g_zoneLockNegBuy=0.0;
   }

   // Rebuild SELL side
   double avgS=0.0; int nSell=CountSell(avgS);
   g_hasOpenSell = (nSell>0);
   g_seriesEntriesSell = nSell;
   if(nSell>0)
   {
      datetime earliestTime = 0; double earliestPrice = 0.0; bool has=false;
      for(int i=0;i<PositionsTotal();++i)
      {
         if(!pos.SelectByIndex(i)) continue;
         if(pos.Symbol()!=_Symbol) continue;
         if((long)pos.Magic()!=(long)MagicNumber) continue;
         if(pos.PositionType()!=POSITION_TYPE_SELL) continue;
         datetime t=(datetime)pos.Time(); double o=pos.PriceOpen();
         if(!has || t<earliestTime){ earliestTime=t; earliestPrice=o; has=true; }
      }
      if(has) g_anchorPriceSell = earliestPrice;
      MarkZoneSell(0);
      // Mark zones for all existing SELL positions relative to anchor
      for(int i=0;i<PositionsTotal();++i)
      {
         if(!pos.SelectByIndex(i)) continue;
         if(pos.Symbol()!=_Symbol) continue;
         if((long)pos.Magic()!=(long)MagicNumber) continue;
         if(pos.PositionType()!=POSITION_TYPE_SELL) continue;
         int zi = ZoneIndexFromBid(pos.PriceOpen());
         MarkZoneSell(zi);
      }
      if(nSell==1)
      {
         double open=0.0; if(GetSingleSell(open))
         {
            double ask=(g_lastAsk>0.0?g_lastAsk:SymbolInfoDouble(_Symbol,SYMBOL_ASK));
            g_singlePeakPipsSell = MathMax(0.0, PriceToPips(open-ask));
            g_singleLockPriceSell = 0.0;
         }
         g_zoneActiveSell=false; g_zonePeakPipsSell=0.0; g_zoneLockPosSell=0.0; g_zoneLockNegSell=0.0;
      }
      else // nSell >= 2
      {
         g_zoneActiveSell=true;
         double ref=ZoneRefPriceSell();
         if(ref>0.0)
         {
            double ask=(g_lastAsk>0.0?g_lastAsk:SymbolInfoDouble(_Symbol,SYMBOL_ASK));
            g_zonePeakPipsSell = MathMax(0.0, PriceToPips(ref-ask));
         }
         g_zoneLockPosSell=0.0; g_zoneLockNegSell=0.0;
         g_singlePeakPipsSell=0.0; g_singleLockPriceSell=0.0;
      }
      g_firstTradeM1Sell = 0;
      g_lastAddTimeSell = (datetime)(TimeCurrent() - MinSecondsBetweenAdds);
   }
   else
   {
      g_anchorPriceSell=0.0; g_firstTradeM1Sell=0; g_singlePeakPipsSell=0.0; g_singleLockPriceSell=0.0;
      g_zoneActiveSell=false; g_zonePeakPipsSell=0.0; g_zoneLockPosSell=0.0; g_zoneLockNegSell=0.0;
   }
}

// dohvat točno jednog
bool GetSingleBuy(double& open)
{
   int found=-1;
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(pos.PositionType()!=POSITION_TYPE_BUY) continue;
      if(found!=-1) return false; found=i;
   }
   if(found==-1) return false; open=pos.PriceOpen(); return true;
}
bool GetSingleSell(double& open)
{
   int found=-1;
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(pos.PositionType()!=POSITION_TYPE_SELL) continue;
      if(found!=-1) return false; found=i;
   }
   if(found==-1) return false; open=pos.PriceOpen(); return true;
}

//============================ NETO PROFIT – KOŠARICA ==============//
double BasketNetProfit(bool buySide) // valuta računa – POSITION_PROFIT uključuje swap/komisije
{
   double sum=0.0;
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(buySide && pos.PositionType()!=POSITION_TYPE_BUY)  continue;
      if(!buySide && pos.PositionType()!=POSITION_TYPE_SELL) continue;
      sum += pos.Profit();
   }
   return sum;
}
//============================ DD HELPERS =============================//
double SideFloatingLoss(bool buySide)
{
   double pnl = BasketNetProfit(buySide);
   return (pnl < 0.0 ? -pnl : 0.0);
}
bool ChillOutBlock(bool buySide)
{
   if(ChillOutDD_Percent <= 0.0) return false;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0.0) return false;
   double loss = SideFloatingLoss(buySide);
   double thr  = eq * (ChillOutDD_Percent/100.0);
   bool hit = (loss >= thr);
   if(hit && EnableDebugPrints) Print(buySide?"[CHILL] BUY side blocked, DD%=" : "[CHILL] SELL side blocked, DD%=", (loss/eq)*100.0);
   return hit;
}
bool EquityProtectTrigger(bool buySide)
{
   if(EquityProtector_Percent <= 0.0) return false;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(eq <= 0.0) return false;
   double loss = SideFloatingLoss(buySide);
   double thr  = eq * (EquityProtector_Percent/100.0);
   return (loss >= thr);
}


//============================ INDIKATORI ==========================//
int  EnsureMAHandle(int& h, ENUM_TIMEFRAMES tf, int per, ENUM_MA_METHOD m, ENUM_APPLIED_PRICE p)
{ if(h==INVALID_HANDLE) h=iMA(_Symbol,tf,per,0,m,p); return h; }

bool EnsureIndicatorHandles()
{
   if(UseHTFTrendFilter)
   {
      if(EnsureMAHandle(hHTF_Fast,HTF_TF,HTF_MA_Fast,HTF_MA_Method,HTF_MA_Price)==INVALID_HANDLE) return false;
      if(EnsureMAHandle(hHTF_Slow,HTF_TF,HTF_MA_Slow,HTF_MA_Method,HTF_MA_Price)==INVALID_HANDLE) return false;
   }
   if(UseEntryCross)
   {
      if(EnsureMAHandle(hEntryMA,EntryTF,Entry_MA_Period,Entry_MA_Method,Entry_MA_Price)==INVALID_HANDLE) return false;
   }
   if(UseRSIFilter)
   {
      if(hRSI==INVALID_HANDLE) hRSI=iRSI(_Symbol,RSI_TF,RSI_Period,PRICE_CLOSE);
      if(hRSI==INVALID_HANDLE) return false;
   }
   if(UseATRFilter || UseATRSpacing)
   {
      if(hATR==INVALID_HANDLE) hATR=iATR(_Symbol,ATR_TF,ATR_Period);
      if(hATR==INVALID_HANDLE) return false;
   }
   return true;
}

void UpdateATRPipsCache()
{
   if(!(UseATRFilter || UseATRSpacing)) return;
   if(!EnsureIndicatorHandles()) return;
   double a[1];
   if(CopyBuffer(hATR,0,0,1,a)==1)
   {
      g_cachedATR_Pips = PriceToPips(a[0]);
      g_cachedATR_Time = TimeCurrent();
   }
}

double GetATRPipsCached()
{
   if(g_cachedATR_Pips>0.0) return g_cachedATR_Pips;
   if(!EnsureIndicatorHandles()) return 0.0;
   double a[1]; if(CopyBuffer(hATR,0,0,1,a)!=1) return 0.0;
   g_cachedATR_Pips = PriceToPips(a[0]);
   g_cachedATR_Time = TimeCurrent();
   return g_cachedATR_Pips;
}

bool HTF_Bullish()
{
   if(!UseHTFTrendFilter) return true;
   if(!EnsureIndicatorHandles()) return false;
   double f[2],s[2];
   if(CopyBuffer(hHTF_Fast,0,1,2,f)!=2) return false;
   if(CopyBuffer(hHTF_Slow,0,1,2,s)!=2) return false;
   return (f[1]>s[1]);
}
bool HTF_Bearish()
{
   if(!UseHTFTrendFilter) return true;
   if(!EnsureIndicatorHandles()) return false;
   double f[2],s[2];
   if(CopyBuffer(hHTF_Fast,0,1,2,f)!=2) return false;
   if(CopyBuffer(hHTF_Slow,0,1,2,s)!=2) return false;
   return (f[1]<s[1]);
}

bool EntryCrossUp()
{
   if(!UseEntryCross) return true;
   if(!EnsureIndicatorHandles()) return false;
   double ma[2],cl[2];
   if(CopyBuffer(hEntryMA,0,1,2,ma)!=2) return false;
   if(CopyClose(_Symbol,EntryTF,1,2,cl)!=2) return false;
   return (cl[1]<=ma[1] && cl[0]>ma[0]);
}
bool EntryCrossDown()
{
   if(!UseEntryCross) return true;
   if(!EnsureIndicatorHandles()) return false;
   double ma[2],cl[2];
   if(CopyBuffer(hEntryMA,0,1,2,ma)!=2) return false;
   if(CopyClose(_Symbol,EntryTF,1,2,cl)!=2) return false;
   return (cl[1]>=ma[1] && cl[0]<ma[0]);
}

bool RSI_AllowsBuy()
{
   if(!UseRSIFilter) return true;
   if(!EnsureIndicatorHandles()) return false;
   double r[1]; if(CopyBuffer(hRSI,0,0,1,r)!=1) return false;
   return (r[0]<=RSI_BuyMax);
}
bool RSI_AllowsSell()
{
   if(!UseRSIFilter) return true;
   if(!EnsureIndicatorHandles()) return false;
   double r[1]; if(CopyBuffer(hRSI,0,0,1,r)!=1) return false;
   return (r[0]>=RSI_SellMin);
}

bool ATR_AllowsEntry()
{
   if(!UseATRFilter) return true;
   if(!EnsureIndicatorHandles()) return false;
   double atrPips = GetATRPipsCached();
   return (atrPips>=ATR_MinPips);
}

// FILTER MATRICA (Anchor vs Zone)
bool AnchorFiltersAllowBuy()
{
   if(!SpreadOK()) return false;
   if(AnchorApply_ATR      && !ATR_AllowsEntry()) return false;
   if(AnchorApply_RSI      && !RSI_AllowsBuy())   return false;
   if(AnchorApply_HTFTrend && !HTF_Bullish())     return false;
   if(AnchorApply_EntryCross && !EntryCrossUp())  return false;
   return true;
}
bool AnchorFiltersAllowSell()
{
   if(!SpreadOK()) return false;
   if(AnchorApply_ATR      && !ATR_AllowsEntry()) return false;
   if(AnchorApply_RSI      && !RSI_AllowsSell())  return false;
   if(AnchorApply_HTFTrend && !HTF_Bearish())     return false;
   if(AnchorApply_EntryCross && !EntryCrossDown())return false;
   return true;
}
bool ZoneFiltersAllowBuy()
{
   if(!SpreadOK()) return false;
   if(ZoneApply_ATR      && !ATR_AllowsEntry()) return false;
   if(ZoneApply_RSI      && !RSI_AllowsBuy())   return false;
   if(ZoneApply_HTFTrend && !HTF_Bullish())     return false;
   if(ZoneApply_EntryCross && !EntryCrossUp())  return false;
   return true;
}
bool ZoneFiltersAllowSell()
{
   if(!SpreadOK()) return false;
   if(ZoneApply_ATR      && !ATR_AllowsEntry()) return false;
   if(ZoneApply_RSI      && !RSI_AllowsSell())  return false;
   if(ZoneApply_HTFTrend && !HTF_Bearish())     return false;
   if(ZoneApply_EntryCross && !EntryCrossDown())return false;
   return true;
}

//============================ OTVARANJE ===========================//
bool OpenBuy(double lots, string why)
{
   if(!CanTradeNow()) return false;
   if(!MarginOK(lots,false)) return false;
   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints());
   bool ok=trade.Buy(lots,_Symbol,0.0,0.0,0.0,why);
   if(ok)
   {
      g_lastTradeTime=TimeCurrent(); g_hasOpenBuy=true; ++g_seriesEntriesBuy;
      g_lastAddTimeBuy = TimeCurrent();
      if(g_seriesEntriesBuy==1)
      {
         g_anchorPriceBuy=(g_lastAsk>0.0?g_lastAsk:SymbolInfoDouble(_Symbol,SYMBOL_ASK));
         g_firstTradeM1Buy=iTime(_Symbol,PERIOD_M1,0);
         ArrayInitialize(g_zoneMarksBuy,0);
         g_singlePeakPipsBuy=0; g_singleLockPriceBuy=0;
         g_zonePeakPipsBuy=0; g_zoneLockPosBuy=0; g_zoneLockNegBuy=0;
         g_zoneActiveBuy=false;
         MarkZoneBuy(0);
      }
      if(EnableDebugPrints) Print("BUY opened: ",why);
   }
   return ok;
}
bool OpenSell(double lots, string why)
{
   if(!CanTradeNow()) return false;
   if(!MarginOK(lots,true)) return false;
   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints());
   bool ok=trade.Sell(lots,_Symbol,0.0,0.0,0.0,why);
   if(ok)
   {
      g_lastTradeTime=TimeCurrent(); g_hasOpenSell=true; ++g_seriesEntriesSell;
      g_lastAddTimeSell = TimeCurrent();
      if(g_seriesEntriesSell==1)
      {
         g_anchorPriceSell=(g_lastBid>0.0?g_lastBid:SymbolInfoDouble(_Symbol,SYMBOL_BID));
         g_firstTradeM1Sell=iTime(_Symbol,PERIOD_M1,0);
         ArrayInitialize(g_zoneMarksSell,0);
         g_singlePeakPipsSell=0; g_singleLockPriceSell=0;
         g_zonePeakPipsSell=0; g_zoneLockPosSell=0; g_zoneLockNegSell=0;
         g_zoneActiveSell=false;
         MarkZoneSell(0);
      }
      if(EnableDebugPrints) Print("SELL opened: ",why);
   }
   return ok;
}

//============================ ZATVARANJE ==========================//
void CloseAllBuys(const string why)
{
   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints());
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(pos.PositionType()!=POSITION_TYPE_BUY) continue;
      trade.PositionClose(pos.Ticket());
   }
   if(EnableDebugPrints) Print("Close ALL BUY: ",why);
   if(RequireNewBarAfterClose) g_blockReentryBarBuy=iTime(_Symbol,PERIOD_M1,0);
   g_hasOpenBuy=false; g_seriesEntriesBuy=0; g_anchorPriceBuy=0;
   g_firstTradeM1Buy=0; g_singlePeakPipsBuy=0; g_singleLockPriceBuy=0;
   g_zonePeakPipsBuy=0; g_zoneLockPosBuy=0; g_zoneLockNegBuy=0;
   g_zoneActiveBuy=false; ArrayInitialize(g_zoneMarksBuy,0);
   HideHLine("TSL_SINGLE_BUY"); HideHLine("TSL_ZONEPOS_BUY"); HideHLine("TSL_ZONENEG_BUY");
}
void CloseAllSells(const string why)
{
   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints());
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(pos.PositionType()!=POSITION_TYPE_SELL) continue;
      trade.PositionClose(pos.Ticket());
   }
   if(EnableDebugPrints) Print("Close ALL SELL: ",why);
   if(RequireNewBarAfterClose) g_blockReentryBarSell=iTime(_Symbol,PERIOD_M1,0);
   g_hasOpenSell=false; g_seriesEntriesSell=0; g_anchorPriceSell=0;
   g_firstTradeM1Sell=0; g_singlePeakPipsSell=0; g_singleLockPriceSell=0;
   g_zonePeakPipsSell=0; g_zoneLockPosSell=0; g_zoneLockNegSell=0;
   g_zoneActiveSell=false; ArrayInitialize(g_zoneMarksSell,0);
   HideHLine("TSL_SINGLE_SELL"); HideHLine("TSL_ZONEPOS_SELL"); HideHLine("TSL_ZONENEG_SELL");
}

//============================ SINGLE TSL ==========================//
void ManageSingleTSL_Buy()
{
   double open=0.0;
   if(!GetSingleBuy(open)) { g_singleLockPriceBuy=0; g_singlePeakPipsBuy=0; HideHLine("TSL_SINGLE_BUY"); return; }

   const double bid=(g_lastBid>0.0?g_lastBid:SymbolInfoDouble(_Symbol,SYMBOL_BID));
   const double profPips=PriceToPips(bid-open);
   const double profMoney=BasketNetProfit(true); // za single = profit te pozicije

   // mora biti realni profit > 0 i pips >= trigger
   if(profMoney<=0.0 || profPips < (double)Single_TSL_Trigger) { g_singleLockPriceBuy=0; HideHLine("TSL_SINGLE_BUY"); return; }

   if(profPips>g_singlePeakPipsBuy) g_singlePeakPipsBuy=profPips;

   const double lockPips=g_singlePeakPipsBuy-(double)Single_TSL_Step;
   const double cand=open+PipsToPrice(lockPips);
   if(g_singleLockPriceBuy==0.0 || cand>g_singleLockPriceBuy) g_singleLockPriceBuy=cand;

   UpdateHLine("TSL_SINGLE_BUY", g_singleLockPriceBuy, clrDeepSkyBlue);
   if(bid<=g_singleLockPriceBuy) CloseAllBuys("Single BUY TSL");
}
void ManageSingleTSL_Sell()
{
   double open=0.0;
   if(!GetSingleSell(open)) { g_singleLockPriceSell=0; g_singlePeakPipsSell=0; HideHLine("TSL_SINGLE_SELL"); return; }

   const double ask=(g_lastAsk>0.0?g_lastAsk:SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   const double profPips=PriceToPips(open-ask);
   const double profMoney=BasketNetProfit(false);

   if(profMoney<=0.0 || profPips < (double)Single_TSL_Trigger) { g_singleLockPriceSell=0; HideHLine("TSL_SINGLE_SELL"); return; }

   if(profPips>g_singlePeakPipsSell) g_singlePeakPipsSell=profPips;

   const double lockPips=g_singlePeakPipsSell-(double)Single_TSL_Step;
   const double cand=open-PipsToPrice(lockPips);
   if(g_singleLockPriceSell==0.0 || cand<g_singleLockPriceSell) g_singleLockPriceSell=cand;

   UpdateHLine("TSL_SINGLE_SELL", g_singleLockPriceSell, clrTomato);
   if(ask>=g_singleLockPriceSell) CloseAllSells("Single SELL TSL");
}

//============================ ZONE TSL ============================//
// ref cijena prema odabiru
double ZoneRefPriceBuy()
{
   if(ZoneTSL_Anchor==ANCHOR_FIRST)   return g_anchorPriceBuy;
   if(ZoneTSL_Anchor==ANCHOR_AVERAGE) { double avg=0; CountBuy(avg); return avg; }
   // WORST (BUY) = najviša open cijena
   double worst=0.0; bool has=false;
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(pos.PositionType()!=POSITION_TYPE_BUY) continue;
      double o=pos.PriceOpen(); if(!has || o>worst){ worst=o; has=true; }
   }
   return has?worst:0.0;
}
double ZoneRefPriceSell()
{
   if(ZoneTSL_Anchor==ANCHOR_FIRST)   return g_anchorPriceSell;
   if(ZoneTSL_Anchor==ANCHOR_AVERAGE) { double avg=0; CountSell(avg); return avg; }
   // WORST (SELL) = najniža open cijena
   double worst=0.0; bool has=false;
   for(int i=0;i<PositionsTotal();++i)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(pos.Symbol()!=_Symbol) continue;
      if((long)pos.Magic()!=(long)MagicNumber) continue;
      if(pos.PositionType()!=POSITION_TYPE_SELL) continue;
      double o=pos.PriceOpen(); if(!has || o<worst){ worst=o; has=true; }
   }
   return has?worst:0.0;
}

void ManageZoneTSL_Buy()
{
   double avg=0.0; int n=CountBuy(avg);

   // n < 2 → nema košarice
   if(n<2)
   {
      g_zoneActiveBuy=false; g_zonePeakPipsBuy=0; g_zoneLockPosBuy=0; g_zoneLockNegBuy=0;
      HideHLine("TSL_ZONEPOS_BUY"); HideHLine("TSL_ZONENEG_BUY");
      return;
   }

   // aktivacija košarice kad imamo 2 ili više pozicija
   if(!g_zoneActiveBuy){ g_zoneActiveBuy=true; g_zonePeakPipsBuy=0; g_zoneLockPosBuy=0; g_zoneLockNegBuy=0; }

   // TSL se smije paliti SAMO ako je realni neto profit košarice > 0
   const double basketMoney = BasketNetProfit(true);
   if(basketMoney<=0.0)
   {
      // ako smo u minusu, drži TSL deaktiviranim i linije sakrivenima
      HideHLine("TSL_ZONEPOS_BUY"); HideHLine("TSL_ZONENEG_BUY");
      return;
   }

   // profit u pipsima prema ref (FIRST/WORST/AVERAGE)
   const double ref=ZoneRefPriceBuy();
   if(ref<=0.0){ HideHLine("TSL_ZONEPOS_BUY"); HideHLine("TSL_ZONENEG_BUY"); return; }

   const double bid=(g_lastBid>0.0?g_lastBid:SymbolInfoDouble(_Symbol,SYMBOL_BID));
   const double prof=PriceToPips(bid-ref);
   if(prof>g_zonePeakPipsBuy) g_zonePeakPipsBuy=prof;

   // POZITIVNI SMJER: okidač je n>=2 (već zadovoljen) + neto profit > 0
   // => trailing odmah po ZonePos_TSL_Step
   {
      const double lockPips = g_zonePeakPipsBuy - (double)ZonePos_TSL_Step;
      const double cand = ref + PipsToPrice(lockPips);
      if(g_zoneLockPosBuy==0.0 || cand>g_zoneLockPosBuy) g_zoneLockPosBuy=cand;
      if(UseBENudge) g_zoneLockPosBuy = MathMax(g_zoneLockPosBuy, ref + PipsToPrice(BENudgePips));
      UpdateHLine("TSL_ZONEPOS_BUY", g_zoneLockPosBuy, clrLime);
      if(bid <= g_zoneLockPosBuy) { CloseAllBuys("Zone BUY TSL (POS)"); return; }
   }

   // NEGATIVNI SMJER: aktivira se tek kad je košarica u plusu (već provjereno) i kad prijeđemo ZoneNeg_TSL_Trigger pips
   if(g_zonePeakPipsBuy >= (double)ZoneNeg_TSL_Trigger)
   {
      const double lockPipsNeg=g_zonePeakPipsBuy-(double)ZoneNeg_TSL_Step;
      const double candNeg=ref + PipsToPrice(lockPipsNeg);
      if(g_zoneLockNegBuy==0.0 || candNeg>g_zoneLockNegBuy) g_zoneLockNegBuy=candNeg;
      UpdateHLine("TSL_ZONENEG_BUY", g_zoneLockNegBuy, clrOrange);
      if(bid <= g_zoneLockNegBuy) { CloseAllBuys("Zone BUY TSL (NEG)"); return; }
   }
   else { g_zoneLockNegBuy=0.0; HideHLine("TSL_ZONENEG_BUY"); }
}

void ManageZoneTSL_Sell()
{
   double avg=0.0; int n=CountSell(avg);

   if(n<2)
   {
      g_zoneActiveSell=false; g_zonePeakPipsSell=0; g_zoneLockPosSell=0; g_zoneLockNegSell=0;
      HideHLine("TSL_ZONEPOS_SELL"); HideHLine("TSL_ZONENEG_SELL");
      return;
   }

   if(!g_zoneActiveSell){ g_zoneActiveSell=true; g_zonePeakPipsSell=0; g_zoneLockPosSell=0; g_zoneLockNegSell=0; }

   const double basketMoney = BasketNetProfit(false);
   if(basketMoney<=0.0)
   {
      HideHLine("TSL_ZONEPOS_SELL"); HideHLine("TSL_ZONENEG_SELL");
      return;
   }

   const double ref=ZoneRefPriceSell();
   if(ref<=0.0){ HideHLine("TSL_ZONEPOS_SELL"); HideHLine("TSL_ZONENEG_SELL"); return; }

   const double ask=(g_lastAsk>0.0?g_lastAsk:SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   const double prof=PriceToPips(ref-ask);
   if(prof>g_zonePeakPipsSell) g_zonePeakPipsSell=prof;

   // POZITIVNI SMJER: n>=2 + neto profit>0 → trailing odmah po ZonePos_TSL_Step
   {
      const double lockPips=g_zonePeakPipsSell-(double)ZonePos_TSL_Step;
      const double cand=ref - PipsToPrice(lockPips);
      if(g_zoneLockPosSell==0.0 || cand<g_zoneLockPosSell) g_zoneLockPosSell=cand;
      if(UseBENudge) g_zoneLockPosSell = MathMin(g_zoneLockPosSell, ref - PipsToPrice(BENudgePips));
      UpdateHLine("TSL_ZONEPOS_SELL", g_zoneLockPosSell, clrLime);
      if(ask >= g_zoneLockPosSell) { CloseAllSells("Zone SELL TSL (POS)"); return; }
   }

   // NEGATIVNI SMJER: neto profit>0 + peak>=ZoneNeg_TSL_Trigger
   if(g_zonePeakPipsSell >= (double)ZoneNeg_TSL_Trigger)
   {
      const double lockPipsNeg=g_zonePeakPipsSell-(double)ZoneNeg_TSL_Step;
      const double candNeg=ref - PipsToPrice(lockPipsNeg);
      if(g_zoneLockNegSell==0.0 || candNeg<g_zoneLockNegSell) g_zoneLockNegSell=candNeg;
      UpdateHLine("TSL_ZONENEG_SELL", g_zoneLockNegSell, clrOrange);
      if(ask >= g_zoneLockNegSell) { CloseAllSells("Zone SELL TSL (NEG)"); return; }
   }
   else { g_zoneLockNegSell=0.0; HideHLine("TSL_ZONENEG_SELL"); }
}

//============================ STRATEGY GATE ========================//
bool StrategyAllowsBuyOpen()
{
   if(Strategy==STRAT_EXIT)      return false;
   if(Strategy==STRAT_ONLY_SELL) return false;
   return true;
}
bool StrategyAllowsSellOpen()
{
   if(Strategy==STRAT_EXIT)      return false;
   if(Strategy==STRAT_ONLY_BUY)  return false;
   return true;
}

//============================ OTVARANJE – GLAVNI TOK ==============//
bool AllAnchorFiltersOK(bool isBuy)
{
   return isBuy ? AnchorFiltersAllowBuy() : AnchorFiltersAllowSell();
}
bool AllZoneFiltersOK(bool isBuy)
{
   return isBuy ? ZoneFiltersAllowBuy() : ZoneFiltersAllowSell();
}

void ProcessBuyOpen()
{
   double avg=0.0; int n=CountBuy(avg);
   if(n==0 && g_hasOpenBuy) return;
   if(ChillOutBlock(true)) return; // DD chill-out: block new BUY entries

   if(n==0 && !g_hasOpenBuy)
   {
      if(!StrategyAllowsBuyOpen() || !UseZoneLogic) return;
      if(RequireNewBarAfterClose && g_blockReentryBarBuy>0)
      { if(iTime(_Symbol,PERIOD_M1,0)==g_blockReentryBarBuy) return; g_blockReentryBarBuy=0; }
      if((TimeCurrent()-g_lastAnchorAttemptBuy)<2) return;
      if(ShouldApplyIndicatorsForZoneIndex(0) && !AllAnchorFiltersOK(true)) return;

      double lot=LotForSeriesBuy();
      if(MaxExposureLotsPerSide>0.0)
      {
         double curLots = TotalLots(true);
         if(curLots + lot > MaxExposureLotsPerSide) return;
      }
      if(OpenBuy(lot,"Anchor")) g_lastAnchorAttemptBuy=TimeCurrent();
      return;
   }

   if(g_seriesEntriesBuy==1 && g_firstTradeM1Buy>0)
      if(iTime(_Symbol,PERIOD_M1,0)==g_firstTradeM1Buy) return;

   if(!UseZoneLogic || !StrategyAllowsBuyOpen()) return;
   const double ask=(g_lastAsk>0.0?g_lastAsk:SymbolInfoDouble(_Symbol,SYMBOL_ASK));
   const int zoneIndex=ZoneIndexFromAsk(ask);
   if(ShouldApplyIndicatorsForZoneIndex(zoneIndex) && !AllZoneFiltersOK(true)) return;

   if((TimeCurrent()-g_lastAddTimeBuy) < (datetime)MinSecondsBetweenAdds) return;

   if(n < MaxPositions && !IsZoneMarkedBuy(zoneIndex))
   {
      double lot=LotForSeriesBuy();
      if(MaxExposureLotsPerSide>0.0)
      {
         double curLots = TotalLots(true);
         if(curLots + lot > MaxExposureLotsPerSide) return;
      }
      if(OpenBuy(lot, StringFormat("Zone %d",zoneIndex))) MarkZoneBuy(zoneIndex);
   }
}
void ProcessSellOpen()
{
   double avg=0.0; int n=CountSell(avg);
   if(n==0 && g_hasOpenSell) return;
   if(ChillOutBlock(false)) return; // DD chill-out: block new SELL entries

   if(n==0 && !g_hasOpenSell)
   {
      if(!StrategyAllowsSellOpen() || !UseZoneLogic) return;
      if(RequireNewBarAfterClose && g_blockReentryBarSell>0)
      { if(iTime(_Symbol,PERIOD_M1,0)==g_blockReentryBarSell) return; g_blockReentryBarSell=0; }
      if((TimeCurrent()-g_lastAnchorAttemptSell)<2) return;
      if(ShouldApplyIndicatorsForZoneIndex(0) && !AllAnchorFiltersOK(false)) return;

      double lot=LotForSeriesSell();
      if(MaxExposureLotsPerSide>0.0)
      {
         double curLots = TotalLots(false);
         if(curLots + lot > MaxExposureLotsPerSide) return;
      }
      if(OpenSell(lot,"Anchor")) g_lastAnchorAttemptSell=TimeCurrent();
      return;
   }

   if(g_seriesEntriesSell==1 && g_firstTradeM1Sell>0)
      if(iTime(_Symbol,PERIOD_M1,0)==g_firstTradeM1Sell) return;

   if(!UseZoneLogic || !StrategyAllowsSellOpen()) return;
   const double bid=(g_lastBid>0.0?g_lastBid:SymbolInfoDouble(_Symbol,SYMBOL_BID));
   const int zoneIndex=ZoneIndexFromBid(bid);
   if(ShouldApplyIndicatorsForZoneIndex(zoneIndex) && !AllZoneFiltersOK(false)) return;

   if((TimeCurrent()-g_lastAddTimeSell) < (datetime)MinSecondsBetweenAdds) return;

   if(n < MaxPositions && !IsZoneMarkedSell(zoneIndex))
   {
      double lot=LotForSeriesSell();
      if(MaxExposureLotsPerSide>0.0)
      {
         double curLots = TotalLots(false);
         if(curLots + lot > MaxExposureLotsPerSide) return;
      }
      if(OpenSell(lot, StringFormat("Zone %d",zoneIndex))) MarkZoneSell(zoneIndex);
   }
}

//============================ LIFECYCLE ============================//
int OnInit()
{
   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints());

   g_anchorPriceBuy=g_anchorPriceSell=0.0;
   g_hasOpenBuy=g_hasOpenSell=false;
   g_seriesEntriesBuy=g_seriesEntriesSell=0;
   g_firstTradeM1Buy=g_firstTradeM1Sell=0;

   g_singlePeakPipsBuy=g_singlePeakPipsSell=0.0;
   g_singleLockPriceBuy=g_singleLockPriceSell=0.0;

   g_zonePeakPipsBuy=g_zonePeakPipsSell=0.0;
   g_zoneLockPosBuy=g_zoneLockNegBuy=0.0;
   g_zoneLockPosSell=g_zoneLockNegSell=0.0;
   g_zoneActiveBuy=g_zoneActiveSell=false;

   g_lastAnchorAttemptBuy=g_lastAnchorAttemptSell=0;
   g_blockReentryBarBuy=g_blockReentryBarSell=0;

   g_lastAddTimeBuy=g_lastAddTimeSell=0;
   g_lastBid=g_lastAsk=0.0;

   ArrayInitialize(g_zoneMarksBuy,0);
   ArrayInitialize(g_zoneMarksSell,0);

   hHTF_Fast=hHTF_Slow=hEntryMA=hRSI=hATR=INVALID_HANDLE;
   g_cachedATR_Pips=0.0;
   g_cachedATR_Time=0;
   RebuildStateFromExistingPositions(); // Call the new function here
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason)
{
   if(hHTF_Fast!=INVALID_HANDLE)  { IndicatorRelease(hHTF_Fast);  hHTF_Fast=INVALID_HANDLE; }
   if(hHTF_Slow!=INVALID_HANDLE)  { IndicatorRelease(hHTF_Slow);  hHTF_Slow=INVALID_HANDLE; }
   if(hEntryMA !=INVALID_HANDLE)  { IndicatorRelease(hEntryMA );  hEntryMA =INVALID_HANDLE; }
   if(hRSI    !=INVALID_HANDLE)   { IndicatorRelease(hRSI     );  hRSI     =INVALID_HANDLE; }
   if(hATR    !=INVALID_HANDLE)   { IndicatorRelease(hATR     );  hATR     =INVALID_HANDLE; }

   HideHLine("TSL_SINGLE_BUY"); HideHLine("TSL_ZONEPOS_BUY"); HideHLine("TSL_ZONENEG_BUY");
   HideHLine("TSL_SINGLE_SELL"); HideHLine("TSL_ZONEPOS_SELL"); HideHLine("TSL_ZONENEG_SELL");
}

//============================ OnTick ===============================//
void OnTick()
{
   // Cache market prices
   g_lastBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_lastAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Update ATR cache if used
   UpdateATRPipsCache();

   // EXIT (TSL)
   if(CountBuy((double&)g_anchorPriceBuy)==1)  ManageSingleTSL_Buy();
   if(CountSell((double&)g_anchorPriceSell)==1) ManageSingleTSL_Sell();
   ManageZoneTSL_Buy();
   ManageZoneTSL_Sell();

   // DD EQUITY PROTECTOR (per side)
   if(EquityProtectTrigger(true))  { if(EnableDebugPrints) Print("[EQUITY PROTECT] Closing BUY basket due to DD%"); CloseAllBuys("Equity protector BUY DD"); }
   if(EquityProtectTrigger(false)) { if(EnableDebugPrints) Print("[EQUITY PROTECT] Closing SELL basket due to DD%"); CloseAllSells("Equity protector SELL DD"); }

   // ENTRY
   ProcessBuyOpen();
   ProcessSellOpen();
}

//============================ OnTradeTransaction ==================//
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest&     req,
                        const MqlTradeResult&      res)
{
   // Bez dodatne obrade; OnTick sve kontrolira
}
//+------------------------------------------------------------------+