//+------------------------------------------------------------------+
//|                                                   BOT_MEDIAS.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Rodrigo Cartaxo."
#property version   "1.00"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <.\Personal\\H9k_Includes\H9k_YT_libs_3.mqh>
#include <.\Personal\cartaxo_Includes\MyMagicNumber.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\TraderInfos.mqh>
#include <.\Personal\cartaxo_Includes\MyCtrader\MyCtrader.mqh>
#include <.\Personal\cartaxo_Includes\MyPainel.mqh>



//+------------------------------------------------------------------+
//| Input Variables                                                  |
//+------------------------------------------------------------------+
input group "==== Params IFR ====";
input int                   iIFRPeriod             = 14;
input ENUM_TIMEFRAMES       iIFRTimeFrame          = PERIOD_M5;
input ENUM_APPLIED_PRICE    iIFRAppliedPrice       = PRICE_CLOSE;
input int                   irRSILevelUpper        = 70;
input int                   irRSILevelLower        = 30;
input group "==== Params EMA ====";
input ENUM_TIMEFRAMES       iEMATimeFrame          = PERIOD_M5;
input ENUM_APPLIED_PRICE    iEMAppliedPrice        = PRICE_CLOSE;
input int                   emaPeriod              = 200;
//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
MyPainel painel;
TraderInfos tradeInfos;


double indBuffer[],emaBuffer[];
MyCtrader trade;
string _sep = ",";
string _V_Currencies[];
int _lenghtArray =0; 

struct SIndicators{
   
   int ema;
   int irf;
   string symbol;

};




MyMagicNumber myMagicNumber;

SIndicators vSIndicators[];
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   
   tradeInfos.iMagicNumber = myMagicNumber.calculate(MQLInfoString(MQL_PROGRAM_NAME),StringSubstr(_Symbol,0,3));
   
   if (!painel.OnInit(myMagicNumber.magicNumber))return INIT_FAILED ;
      
   
   ushort sep_code = StringGetCharacter(_sep,0);
   _lenghtArray = StringSplit(currencies,sep_code,_V_Currencies);
   
   ArrayResize(vSIndicators,_lenghtArray);
  
   for(int i=_lenghtArray-1;i>=0;i-- ){
       vSIndicators[i]=  initIndicators(_V_Currencies[i]);
   }
  
  ArraySetAsSeries(indBuffer, true);
  ArraySetAsSeries(emaBuffer, true);
  
   EventSetTimer(1);  

   return(INIT_SUCCEEDED);
  }
  
SIndicators initIndicators(string symbol){
   SIndicators s;
   
   Print("Init iRSI ",symbol );
     
   int tempRSi = iRSI(symbol, iIFRTimeFrame, iIFRPeriod, iIFRAppliedPrice);
   if (tempRSi == INVALID_HANDLE){
     Alert(" Failed to create  ifrHandle ");    
   };
   
   Print("Init iMA ",symbol );

   int tempEma = iMA(symbol,iEMATimeFrame,emaPeriod,1,MODE_EMA,iEMAppliedPrice); 
    if (tempEma == INVALID_HANDLE){
      Alert(" Failed to create  EMAHandle ");
      
   };  
   
   s.symbol = symbol;
   s.irf = tempRSi;
   s.ema = tempEma;
   
   return s ;


}
  
  
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
   // Properly release indicator handles
   for(int i = 0; i < _lenghtArray; i++) {
      if(vSIndicators[i].irf != INVALID_HANDLE) {
         IndicatorRelease(vSIndicators[i].irf);
         vSIndicators[i].irf = INVALID_HANDLE;
      }
      if(vSIndicators[i].ema != INVALID_HANDLE) {
         IndicatorRelease(vSIndicators[i].ema);
         vSIndicators[i].ema = INVALID_HANDLE;
      }
   }
   
    ArrayFree(indBuffer);
    ArrayFree(emaBuffer);
   
   // Destroy panel and reset timer
   painel.Destroy(reason);  
   EventKillTimer();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
    if (!isNewBar())return;
    
    painel.OnTick();
    
    for(int i=_lenghtArray-1;i>=0;i--) {
        SIndicators indic = vSIndicators[i];
        
      if(CopyBuffer(indic.ema,0,0,2,emaBuffer) < 0) {
            Print("Error copying EMA buffer: ", GetLastError());
            return;
       }
      
       if(CopyBuffer(indic.irf,0,0,4,indBuffer) < 0) {
            Print("Error copying IRF buffer: ", GetLastError());
            return;
       } 
       
       double ema = emaBuffer[1];
       double rsi_1 = indBuffer[1];
       double rsi_2 = indBuffer[2];
       
        
        double price_step = SymbolInfoDouble(indic.symbol, SYMBOL_TRADE_TICK_SIZE);
        double close = iClose(indic.symbol, iTradeTimeFrame, 1);
        
        tradeInfos.symbol = indic.symbol;
        tradeInfos.message = MQLInfoString(MQL_PROGRAM_NAME) + " " + indic.symbol;
        
        if (HasPosition(tradeInfos.iMagicNumber,indic.symbol)!=0) return;
        
        // Buy condition
        if(rsi_1 < irRSILevelLower && rsi_2 > irRSILevelLower ) {
            double entry_price = SymbolInfoDouble(indic.symbol, SYMBOL_ASK);
            
            // Check if price is valid for new buy trade
            
            double sl = roundPriceH9K(entry_price - (entry_price * iStopLossPercent/100), price_step);
            double tp = roundPriceH9K(entry_price + (entry_price * iTakeProfitPercent/100), price_step);
                
            tradeInfos.amount = entry_price;
            tradeInfos.order_type = ORDER_TYPE_BUY;
            tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
            tradeInfos.stop_loss = sl;
            tradeInfos.take_profit = tp;
                
                
            trade.sendOrder(tradeInfos);
                
            
        }
        
        // Sell condition
        if(rsi_1 > irRSILevelUpper && rsi_2 < irRSILevelUpper) {
            double entry_price = SymbolInfoDouble(indic.symbol, SYMBOL_BID);
            
            // Check if price is valid for new sell trade
            double sl = roundPriceH9K(entry_price + (entry_price * iStopLossPercent/100), price_step);
            double tp = roundPriceH9K(entry_price - (entry_price * iTakeProfitPercent/100), price_step);
                
            tradeInfos.amount = entry_price;
            tradeInfos.order_type = ORDER_TYPE_SELL;
            tradeInfos.order_type_time = i24h ? ORDER_TIME_GTC : ORDER_TIME_DAY;
            tradeInfos.stop_loss = sl;
            tradeInfos.take_profit = tp;
                
            trade.sendOrder(tradeInfos);
            
                
            }
        }
 }



void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam){
   
   painel.PanelChartEvent(id,lparam,dparam,sparam );
   
}
void OnTimer(){
   painel.OnTimer();
}

