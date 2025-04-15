#property copyright "Mr CapFree"
#property link      "https://www.MrCapFree.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
   CTrade            trade;
   CPositionInfo     posinfo;      
   COrderInfo        ordinfo;

      enum     enumLotType{Fixed_Lots=0, Pct_of_Balance=1, Pct_of_Equity=2, Pct_of_Free_Margin=3};
      enum     enumHour{Inactive=0, _0100=1, _0200=2, _0300=3, _0400=4, _0500=5, _0600=6, _0700=7, _0800=8, _0900=9, _1000=10, _1100=11, _1200=12, _1300=13, _1400=14, _1500=15, _1600=16, _1700=17, _1800=18, _1900=19, _2000=20, _2100=21, _2200=22, _2300=23};

input group "====== Moving Average Profiles ======"

   input    ENUM_TIMEFRAMES      TradingTimeFrame           =     PERIOD_M5;           // Timeframe for Trading
   input    int                  TradingMAFastest_Period    =     8;                   // Fastest MA for Trading chart
   input    int                  TradingMAMiddle_Period     =     13;                  // Middle MA for Trading Chart
   input    int                  TradingMASlowest_Period    =     21;                  // Slowest MA for Trading Chart
   input    ENUM_TIMEFRAMES      TrendTimeFrame             =     PERIOD_H1;           // Timeframe for Trend direction
   input    int                  TrendMAFast_Period         =     13;                  // Fast MA for Trend
   input    int                  TrendMASlow_Period         =     21;                  // Slow MA for Trend
   input    ENUM_MA_METHOD       MA_Mode                    =     MODE_EMA;            // MA Mode
   input    ENUM_APPLIED_PRICE   MA_AppliedPrice            =     PRICE_MEDIAN;        // MA Applied Price

input group "====== EA related Variables ======"

   input    enumLotType          LotType              =     1;                   // Type of Lotsize (Fixed or % Risk)
   input    double               FixedLots            =     0.01;                // Fixed Lots (if selected)
   input    double               RiskPercent          =     2;                   //Risk in % on each trade
   input    ulong                InpMagic             =     13847;               // EA identification No (Magic No)
   input    enumHour             SHInput              =     7;                   // Trading Start Hour
   input    enumHour             EHInput              =     21;                  // Trading End Hour
   input    int                  ExpirationBars       =     12;

//======= General Global Variables ==============

   int handleTradingMA_Fastest, handleTradingMA_Middle, handleTradingMA_Slowest, handleTrendMA_Fast, handleTrendMA_Slow;
   double IndBuffer[];
   double TradingMA_Fastest, TradingMA_Middle, TradingMA_Slowest, TrendMA_Fast, TrendMA_Slow;
   int   BuyTotal, SellTotal;


int OnInit(){

   trade.SetExpertMagicNumber(InpMagic);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_AUTOSCROLL,true);
   ChartSetInteger(0,CHART_SHIFT,true);
   ChartSetInteger(0,CHART_SHOW_VOLUMES,false);
   

   handleTradingMA_Fastest    = iMA(_Symbol,TradingTimeFrame,TradingMAFastest_Period,1,MA_Mode,MA_AppliedPrice);
   handleTradingMA_Middle     = iMA(_Symbol,TradingTimeFrame,TradingMAMiddle_Period,1,MA_Mode,MA_AppliedPrice);
   handleTradingMA_Slowest    = iMA(_Symbol,TradingTimeFrame,TradingMASlowest_Period,1,MA_Mode,MA_AppliedPrice);
   handleTrendMA_Fast         = iMA(_Symbol,TrendTimeFrame,TrendMAFast_Period,1,MA_Mode,MA_AppliedPrice);
   handleTrendMA_Slow         = iMA(_Symbol,TrendTimeFrame,TrendMASlow_Period,1,MA_Mode,MA_AppliedPrice);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

   IndicatorRelease(handleTradingMA_Fastest);
   IndicatorRelease(handleTradingMA_Middle);
   IndicatorRelease(handleTradingMA_Slowest);
   IndicatorRelease(handleTrendMA_Fast);
   IndicatorRelease(handleTradingMA_Middle);
}


void OnTick(){

   if(IsOnePositionClosed()) SettoBreakEven();
   
   if(!IsNewBar()) return;

   MqlDateTime time;
   TimeToStruct(TimeCurrent(),time);  

   int Hournow = time.hour;   

   if(Hournow<SHInput){CloseAllOrders(); return;}
   if(Hournow>=EHInput && EHInput!=0){CloseAllOrders(); return;}   

   AssignEMAValues();
   
   double Open1x  = iOpen(_Symbol,TradingTimeFrame,1);
   double Low1x   = iLow(_Symbol,TradingTimeFrame,1);
   double High1x  = iHigh(_Symbol,TradingTimeFrame,1);
   
   int    Lowestx5   = iLowest(_Symbol,TradingTimeFrame,MODE_LOW,5,1);
   double Low5x      = iLow(_Symbol,TradingTimeFrame,Lowestx5);
   int    Highestx5  = iHighest(_Symbol,TradingTimeFrame,MODE_HIGH,5,1);
   double Highx5     = iHigh(_Symbol,TradingTimeFrame,Highestx5);
   
   
    BuyTotal=0;
    SellTotal=0;

   for (int i=OrdersTotal()-1; i>=0; i--){
      ordinfo.SelectByIndex(i);
      if(ordinfo.OrderType()==ORDER_TYPE_BUY_STOP && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic) BuyTotal++;   
      if(ordinfo.OrderType()==ORDER_TYPE_SELL_STOP && ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic) SellTotal++;
   }   

   for (int i=PositionsTotal()-1; i>=0; i--){
      posinfo.SelectByIndex(i);
      if(posinfo.PositionType()==POSITION_TYPE_BUY && posinfo.Symbol()==_Symbol && posinfo.Magic()==InpMagic) BuyTotal++;   
      if(posinfo.PositionType()==POSITION_TYPE_SELL && posinfo.Symbol()==_Symbol && posinfo.Magic()==InpMagic) SellTotal++;
   }   
   
// Checking for Buy Conditions
   if(      TradingMA_Fastest > TradingMA_Middle
         && TradingMA_Middle  > TradingMA_Slowest
         && TrendMA_Fast      > TrendMA_Slow
         && Open1x            > TradingMA_Fastest
         && Low1x             < TradingMA_Fastest
         && Low1x             > TradingMA_Slowest    
         && BuyTotal          < 1
     ){

           double    entry       = Highx5 + 30*_Point;
           double    sl          = Low1x - 30*_Point;
           double    tp1         = entry + (entry - sl);
           double    tp2         = entry + ((entry - sl)*2);
           double    lots        = calcLots(entry-sl);
           datetime  expiration  = iTime(_Symbol,TradingTimeFrame,0) + ExpirationBars * PeriodSeconds(TradingTimeFrame);

           trade.BuyStop(lots,entry,_Symbol,sl,tp1,ORDER_TIME_SPECIFIED,expiration,"Mr CapFree");
           trade.BuyStop(lots,entry,_Symbol,sl,tp2,ORDER_TIME_SPECIFIED,expiration,"Mr CapFree");
   }

// Checking for Sell Conditions
   if(      TradingMA_Fastest < TradingMA_Middle
         && TradingMA_Middle  < TradingMA_Slowest
         && TrendMA_Fast      < TrendMA_Slow
         && Open1x            < TradingMA_Fastest
         && High1x            > TradingMA_Fastest
         && High1x            < TradingMA_Slowest    
         && SellTotal         < 1
     ){
           double    entry       = Low5x - 30*_Point;
           double    sl          = High1x + 30*_Point;
           double    tp1         = entry - (sl - entry);
           double    tp2         = entry - ((sl - entry)*2);
           double    lots        = calcLots(sl-entry);
           datetime  expiration  = iTime(_Symbol,TradingTimeFrame,0) + ExpirationBars * PeriodSeconds(TradingTimeFrame);
           
           trade.SellStop(lots,entry,_Symbol,sl,tp1,ORDER_TIME_SPECIFIED,expiration,"Mr CapFree");
           trade.SellStop(lots,entry,_Symbol,sl,tp2,ORDER_TIME_SPECIFIED,expiration,"Mr CapFree");
   }


}

//+------------------------------------------------------------------+

bool IsNewBar(){
      static datetime previousTime = 0;
      datetime currentTime = iTime(_Symbol,TradingTimeFrame,0);
      if(previousTime!=currentTime){
         previousTime=currentTime;
         return true;
      }
      return false;
}


void AssignEMAValues(){

   CopyBuffer(handleTradingMA_Fastest,0,1,1,IndBuffer);
   TradingMA_Fastest = IndBuffer[0];
        
   CopyBuffer(handleTradingMA_Middle,0,1,1,IndBuffer);
   TradingMA_Middle = IndBuffer[0];

   CopyBuffer(handleTradingMA_Slowest,0,1,1,IndBuffer);
   TradingMA_Slowest = IndBuffer[0];

   CopyBuffer(handleTrendMA_Fast,0,1,1,IndBuffer);
   TrendMA_Fast = IndBuffer[0];

   CopyBuffer(handleTrendMA_Slow,0,1,1,IndBuffer);
   TrendMA_Slow = IndBuffer[0];
   
}

double calcLots(double slPoints){

      double lots = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);

      double AccountBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
      double EquityBalance    = AccountInfoDouble(ACCOUNT_EQUITY);
      double FreeMargin       = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

      double risk=0;

      switch(LotType){
         case 0: lots=  FixedLots; return lots;
         case 1: risk = (AccountBalance * RiskPercent / 100)/4; break;
         case 2: risk = (EquityBalance * RiskPercent / 100)/4; break;
         case 3: risk = (FreeMargin * RiskPercent / 100)/4; break;
      }
      
      double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
      double lotstep = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);

      double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
             lots = MathFloor(risk / moneyPerLotstep) * lotstep;

      double minvolume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
      double maxvolume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
      double volumelimit = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_LIMIT);
      
      if(volumelimit!=0) lots = MathMin(lots,volumelimit);
      if(maxvolume!=0) lots = MathMin(lots,maxvolume);
      if(minvolume!=0) lots = MathMax(lots,minvolume);
      lots = NormalizeDouble(lots,2);

      return lots;

}

void CloseAllOrders(){

   for(int i=OrdersTotal()-1;i>=0;i--){
      ordinfo.SelectByIndex(i);
      ulong ticket = ordinfo.Ticket();
      if(ordinfo.Symbol()==_Symbol && ordinfo.Magic()==InpMagic){
         trade.OrderDelete(ticket);
      }
   }

}

void SettoBreakEven(){
      for(int i=PositionsTotal()-1; i>=0; i--){
         posinfo.SelectByIndex(i);
         if(posinfo.Magic()==InpMagic && posinfo.Symbol()==_Symbol){
            ulong ticket = posinfo.Ticket();
            double entry = posinfo.PriceOpen();
            if(posinfo.PositionType()==POSITION_TYPE_BUY){
               trade.PositionModify(ticket,entry+5*_Point,posinfo.TakeProfit());
            }
            if(posinfo.PositionType()==POSITION_TYPE_SELL){
                trade.PositionModify(ticket,entry-5*_Point,posinfo.TakeProfit());
            }
         }
      }
}

bool IsOnePositionClosed(){
      static int PosTotalprv = 0;
      int PosTotalcurr = PositionsTotal();
         if(PosTotalcurr==2 && PosTotalprv!=PosTotalcurr){
            PosTotalprv=PosTotalcurr;
         }
         if(PosTotalprv==2 && PosTotalcurr==1){
            PosTotalprv=PosTotalcurr;
            return true;
         }
      return false;
}
